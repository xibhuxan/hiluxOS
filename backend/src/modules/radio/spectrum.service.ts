import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { spawn, ChildProcessWithoutNullStreams } from 'child_process';
import { EventsGateway } from '../events/events.gateway';

/**
 * SpectrumService — Backend-side real-time audio analysis (Option B).
 *
 * Uses a **ring buffer** (circular buffer) architecture: ffmpeg writes PCM
 * samples into a fixed-size circular buffer, and the analysis timer reads
 * from it at a steady real-time pace, always trailing the writer by a
 * prudential lag (~2 s). This absorbs network jitter (Zeno.fm delivers in
 * bursts with 1–4 s gaps) without freezing the visualizer:
 *
 *  - During a network gap, the reader naturally catches up to the writer
 *    (lag shrinks). Short gaps (< lag) are fully absorbed — no stale frames.
 *  - When the gap exceeds the lag, the reader underruns → gentle decay +
 *    BUFFERING flag after 500 ms tolerance.
 *  - When a burst arrives after a gap, the writer jumps ahead. If the lag
 *    exceeds MAX_LAG (~5 s), the reader jumps forward to re-establish the
 *    target lag — always showing recent audio, never processing stale data.
 *
 * The ring buffer replaces a linear `Buffer` with `concat`/`subarray` (which
 * copied memory on every chunk and grew unboundedly). The ring is fixed-size,
 * zero-allocation per frame, and handles bursty delivery naturally.
 *
 * CPU cost (benchmarked on i5-8300H): ~0.8% of one core total
 * (FFT 0.07% + ffmpeg 0.7%). Estimated ~5% of one core on Raspberry Pi 4.
 *
 * The service tracks active streams by URL so multiple listeners on the same
 * station share a single ffmpeg process. When the last listener for a URL
 * disconnects (or calls stop), the process is killed.
 */
@Injectable()
export class SpectrumService implements OnModuleDestroy {
  private readonly logger = new Logger(SpectrumService.name);

  /** FFT configuration — tuned for minimal CPU while covering audible range. */
  private static readonly FFT_SIZE = 1024;
  /** Sliding-window hop (75% overlap) → ~31 fresh frames/s @ 8 kHz. */
  private static readonly HOP_SIZE = 256;
  private static readonly SAMPLE_RATE = 8000;
  private static readonly BAND_COUNT = 48;
  private static readonly MIN_FREQ = 30;
  private static readonly MAX_FREQ = 4000;

  /** Ring buffer: target lag the reader maintains behind the writer.
   *  2 s absorbs Zeno.fm's typical 1–2 s network gaps without stale frames. */
  private static readonly TARGET_LAG_SECONDS = 2;
  /** If the reader falls more than this behind the writer, jump forward to
   *  re-establish TARGET_LAG — prevents processing very old audio after a
   *  long gap + burst cycle. */
  private static readonly MAX_LAG_SECONDS = 5;
  /** Ring buffer capacity — large enough for MAX_LAG + FFT_SIZE + headroom. */
  private static readonly RING_CAPACITY_SECONDS = 10;

  /** Underrun tolerance: don't flag stale until the buffer has been dry for
   *  this long. Absorbs sub-second network hiccups. */
  private static readonly UNDERRUN_TOLERANCE_MS = 500;

  /** Temporal EMA smoothing factor per band (0 = frozen, 1 = raw). */
  private static readonly EMA_ALPHA = 0.35;

  /** AGC: how fast the running peak reference decays (per frame). */
  private static readonly AGC_DECAY = 0.999;
  /** AGC: minimum peak reference — prevents noise floor from saturating. */
  private static readonly AGC_FLOOR = 0.12;

  /** Target push rate to the WebSocket (frames per second). */
  private static readonly PUSH_FPS = 30;

  /** Active streams keyed by URL. */
  private readonly streams = new Map<
    string,
    {
      proc: ChildProcessWithoutNullStreams;
      listeners: Set<string>;
      /** Fixed-size circular PCM buffer (Float32 samples). */
      ring: Float32Array;
      /** Absolute write position (monotonically increasing; mod capacity for access). */
      writePos: number;
      /** Absolute read position (monotonically increasing; mod capacity for access). */
      readPos: number;
      /** Scratch buffer for the FFT window (handles ring wraparound). */
      windowScratch: Float32Array;
      hann: Float64Array;
      twiddle: Float64Array;
      bitReversal: Uint32Array;
      bandEdges: number[];
      /** Scratch buffers reused across frames — zero per-frame allocation. */
      re: Float64Array;
      im: Float64Array;
      mag: Float64Array;
      /** Temporally smoothed band values (the EMA state). */
      bandSmooth: Float64Array;
      /** AGC running peak reference for loudness normalization. */
      agcPeak: number;
      /** Latest computed band frame — pushed to clients by the fixed-rate timer. */
      latestBands: number[] | null;
      /** Wall-clock time of the last analysis tick (diagnostics). */
      lastTickAt: number;
      /** True once the initial target lag has been established and steady
       *  consumption has started. Before this, the ring is still filling. */
      started: boolean;
      /** Wall-clock time when the ring first ran dry (0 when not dry).
       *  Used to tolerate short underruns (< 500 ms) without flagging stale. */
      underrunSince: number;
      /** True when the ring buffer is empty (network underrun) so clients can
       *  show a BUFFERING state instead of a frozen frame. */
      stale: boolean;
      /** Fixed-rate broadcast timer (≈30 fps) for this stream. */
      pushTimer: NodeJS.Timeout;
    }
  >();

  /** Map of listenerId → URL so we can clean up on stop. */
  private readonly listenerUrls = new Map<string, string>();

  constructor(private readonly events: EventsGateway) {}

  // ── Public API ──────────────────────────────────────────────────────────

  /**
   * Start spectrum analysis for a stream URL on behalf of a listener.
   * If a stream for this URL is already active, the listener is just added
   * to the set (process sharing).
   */
  startAnalysis(listenerId: string, url: string): void {
    // If this listener was already tracking a different URL, stop that first.
    const prevUrl = this.listenerUrls.get(listenerId);
    if (prevUrl && prevUrl !== url) {
      this.stopAnalysis(listenerId);
    }

    this.listenerUrls.set(listenerId, url);

    let entry = this.streams.get(url);
    if (entry) {
      entry.listeners.add(listenerId);
      this.logger.log(
        `Listener ${listenerId} joined existing stream (${entry.listeners.size} total)`,
      );
      return;
    }

    // New stream — spawn ffmpeg and precompute FFT tables.
    this.logger.log(`Starting spectrum analysis for ${listenerId}: ${url}`);
    const proc = this.spawnFfmpeg(url);
    const hann = this.precomputeHann(SpectrumService.FFT_SIZE);
    const twiddle = this.precomputeTwiddle(SpectrumService.FFT_SIZE);
    const bitReversal = this.precomputeBitReversal(SpectrumService.FFT_SIZE);
    const bandEdges = this.computeBandEdges(
      SpectrumService.BAND_COUNT,
      SpectrumService.MIN_FREQ,
      SpectrumService.MAX_FREQ,
      SpectrumService.SAMPLE_RATE,
      SpectrumService.FFT_SIZE,
    );

    const ringCapacity =
      SpectrumService.SAMPLE_RATE * SpectrumService.RING_CAPACITY_SECONDS;

    entry = {
      proc,
      listeners: new Set([listenerId]),
      ring: new Float32Array(ringCapacity),
      writePos: 0,
      readPos: 0,
      windowScratch: new Float32Array(SpectrumService.FFT_SIZE),
      hann,
      twiddle,
      bitReversal,
      bandEdges,
      re: new Float64Array(SpectrumService.FFT_SIZE),
      im: new Float64Array(SpectrumService.FFT_SIZE),
      mag: new Float64Array(SpectrumService.FFT_SIZE / 2),
      bandSmooth: new Float64Array(SpectrumService.BAND_COUNT),
      agcPeak: 0,
      latestBands: null,
      started: false,
      underrunSince: 0,
      stale: false,
      lastTickAt: Date.now(),
      pushTimer: setInterval(
        () => {
          const e = this.streams.get(url);
          if (!e) return;

          const now = Date.now();
          e.lastTickAt = now;
          const lag = e.writePos - e.readPos; // samples available to read
          const targetLag =
            SpectrumService.SAMPLE_RATE * SpectrumService.TARGET_LAG_SECONDS;
          const maxLag =
            SpectrumService.SAMPLE_RATE * SpectrumService.MAX_LAG_SECONDS;

          // ── Phase 1: Establish initial lag (ring fill-up) ──────────────
          // Wait until the writer is TARGET_LAG ahead of the reader before
          // starting consumption. This is the "prudential distance": the
          // reader always trails by ~2 s, so short network gaps (< 2 s) are
          // absorbed silently. This replaces the old 3 s prebuffer — same
          // idea, but integrated into the ring's natural geometry.
          if (!e.started) {
            if (lag >= targetLag) {
              e.started = true;
              // Set readPos to exactly TARGET_LAG behind writePos.
              e.readPos = e.writePos - targetLag;
            } else {
              // Still filling — broadcast a zero/priming frame.
              if (!e.latestBands) {
                e.latestBands = new Array(SpectrumService.BAND_COUNT).fill(0);
              }
              this.events.broadcast('spectrum', {
                bands: e.latestBands,
                stale: false,
              });
              return;
            }
          }

          // ── Phase 2: Lag management (the ring's core logic) ────────────
          // If the writer has jumped far ahead (burst after a gap), cap the
          // lag so we don't process very old audio. Jump the reader forward
          // to re-establish TARGET_LAG — always show recent audio.
          if (lag > maxLag) {
            e.readPos = e.writePos - targetLag;
          }

          // ── Phase 3: Consume one HOP per tick (steady ~31 fps) ─────────
          // Each tick reads exactly one HOP (256 samples) from the ring and
          // advances the read position. The FFT window is the last FFT_SIZE
          // samples ending at the new readPos (75% overlap with the previous
          // frame). If the ring is dry (underrun), decay + flag stale.
          const avail = e.writePos - e.readPos;
          if (avail >= SpectrumService.HOP_SIZE) {
            // Read the FFT window: the last FFT_SIZE samples ending at
            // (readPos + HOP_SIZE). Copy into windowScratch handling wraparound.
            const windowEnd = e.readPos + SpectrumService.HOP_SIZE;
            const windowStart = windowEnd - SpectrumService.FFT_SIZE;
            this.readRingWindow(e, windowStart, windowEnd);

            e.readPos = windowEnd;
            this.computeBandsInto(e);
            e.stale = false;
            e.underrunSince = 0;
          } else {
            // Underrun: the reader has caught up to the writer (network gap
            // exceeded the lag). Tolerate short gaps, decay gently, flag stale
            // only after UNDERRUN_TOLERANCE_MS.
            if (e.underrunSince === 0) e.underrunSince = now;
            const underrunMs = now - e.underrunSince;
            e.stale = underrunMs > SpectrumService.UNDERRUN_TOLERANCE_MS;
            if (e.latestBands) {
              const decay = e.stale ? 0.92 : 0.97;
              for (let b = 0; b < e.latestBands.length; b++) {
                e.latestBands[b] *= decay;
                if (e.latestBands[b] < 0.005) e.latestBands[b] = 0;
              }
            }
          }

          if (e.latestBands) {
            this.events.broadcast('spectrum', {
              bands: e.latestBands,
              stale: e.stale,
            });
          }
        },
        // Timer cadence = exactly one HOP of real-time per tick (32 ms at
        // 8 kHz / 256-sample HOP). This guarantees each tick consumes exactly
        // one HOP → one frame per tick, steady ~31 fps.
        Math.round(
          (SpectrumService.HOP_SIZE / SpectrumService.SAMPLE_RATE) * 1000,
        ),
      ),
    };
    this.streams.set(url, entry);

    proc.stdout.on('data', (chunk: Buffer) => this.onAudioData(url, entry!, chunk));
    proc.stderr.on('data', (data: Buffer) => {
      const msg = data.toString().trim();
      if (msg && !msg.startsWith('frame=') && !msg.startsWith('size=')) {
        this.logger.debug(`ffmpeg: ${msg}`);
      }
    });
    proc.on('error', (err) => {
      this.logger.error(`ffmpeg error for ${url}: ${err.message}`);
      this.cleanupStream(url);
    });
    proc.on('close', (code) => {
      this.logger.log(`ffmpeg exited (code ${code}) for ${url}`);
      this.cleanupStream(url);
    });
  }

  /**
   * Stop spectrum analysis for a listener. If this was the last listener for
   * the URL, the ffmpeg process is killed.
   */
  stopAnalysis(listenerId: string): void {
    const url = this.listenerUrls.get(listenerId);
    if (!url) return;
    this.listenerUrls.delete(listenerId);

    const entry = this.streams.get(url);
    if (!entry) return;

    entry.listeners.delete(listenerId);
    if (entry.listeners.size === 0) {
      this.logger.log(`Stopping spectrum analysis for ${url} (no listeners left)`);
      this.cleanupStream(url);
    } else {
      this.logger.log(
        `Listener ${listenerId} left stream (${entry.listeners.size} remaining)`,
      );
    }
  }

  /** Gracefully stop all streams on module shutdown. */
  onModuleDestroy(): void {
    for (const url of [...this.streams.keys()]) {
      this.cleanupStream(url);
    }
  }

  // ── ffmpeg spawning ─────────────────────────────────────────────────────

  private spawnFfmpeg(url: string): ChildProcessWithoutNullStreams {
    return spawn(
      'ffmpeg',
      [
        '-reconnect', '1', // auto-reconnect on network drops
        '-reconnect_streamed', '1',
        '-reconnect_delay_max', '2',
        '-rw_timeout', '5000000', // 5 s I/O timeout (microseconds)
        '-i',
        url,
        '-vn', // no video
        '-ar',
        String(SpectrumService.SAMPLE_RATE), // 8 kHz
        '-ac',
        '1', // mono
        '-af', 'aresample=async=1', // keep audio in sync
        '-f',
        'f32le', // 32-bit float little-endian PCM
        '-loglevel',
        'warning',
        'pipe:1', // output to stdout
      ],
      {
        stdio: ['pipe', 'pipe', 'pipe'],
        env: { ...process.env, AV_LOG_FORCE_NOCOLOR: '1' },
      },
    );
  }

  // ── Audio data processing ──────────────────────────────────────────────

  /**
   * Accumulate f32le PCM data from ffmpeg into the ring buffer. Consumption
   * happens on the fixed-rate push timer (one HOP per tick), NOT here — ffmpeg
   * delivers PCM in bursts, so consuming on chunk arrival would produce
   * spectrum jumps once per burst instead of a steady ~31 fps.
   *
   * The ring buffer overwrites old data when it wraps around. This is fine:
   * the reader trails the writer by TARGET_LAG, and if the writer laps the
   * reader (lag > capacity), the lag-management logic in the timer jumps the
   * reader forward. The 10 s capacity is far larger than MAX_LAG (5 s).
   */
  private onAudioData(
    url: string,
    entry: NonNullable<ReturnType<typeof this.streams.get>>,
    chunk: Buffer,
  ): void {
    const ring = entry.ring;
    const capacity = ring.length;
    const numSamples = chunk.length / 4; // f32le = 4 bytes/sample

    for (let i = 0; i < numSamples; i++) {
      const pos = (entry.writePos + i) % capacity;
      ring[pos] = chunk.readFloatLE(i * 4);
    }
    entry.writePos += numSamples;

    // Guard against unbounded position growth: if positions get very large,
    // normalize them down by the capacity to keep numbers manageable.
    // (Float32Array indexing uses % capacity anyway, but writePos/readPos
    // are plain numbers — keep them bounded to avoid precision loss.)
    if (entry.writePos > 1e9) {
      const offset = entry.writePos - entry.readPos;
      entry.writePos = offset;
      entry.readPos = 0;
    }
  }

  /**
   * Read FFT_SIZE samples from the ring buffer ending at `windowEnd` (exclusive)
   * into `entry.windowScratch`, handling wraparound AND negative start
   * positions (which occur on the very first frame when readPos ≈ 0 but
   * FFT_SIZE > HOP_SIZE). Negative positions are zero-filled — this only
   * affects the first ~3 frames and is sonically negligible.
   */
  private readRingWindow(
    entry: NonNullable<ReturnType<typeof this.streams.get>>,
    windowStart: number,
    windowEnd: number,
  ): void {
    const ring = entry.ring;
    const capacity = ring.length;
    const scratch = entry.windowScratch;
    const len = windowEnd - windowStart;

    // Zero-fill any leading negative samples (first-frame edge case).
    let zeroLen = 0;
    let effectiveStart = windowStart;
    if (windowStart < 0) {
      zeroLen = Math.min(-windowStart, len);
      effectiveStart = 0;
      for (let i = 0; i < zeroLen; i++) {
        scratch[i] = 0;
      }
    }
    const remaining = len - zeroLen;
    if (remaining <= 0) return;

    // Fast path: no wraparound — single contiguous copy.
    const startMod = ((effectiveStart % capacity) + capacity) % capacity;
    if (startMod + remaining <= capacity) {
      scratch.set(ring.subarray(startMod, startMod + remaining), zeroLen);
    } else {
      // Wraparound: copy in two parts.
      const firstLen = capacity - startMod;
      scratch.set(ring.subarray(startMod, capacity), zeroLen);
      scratch.set(ring.subarray(0, remaining - firstLen), zeroLen + firstLen);
    }
  }

  // ── FFT pipeline ─────────────────────────────────────────────────────────

  /**
   * Read the FFT_SIZE window from windowScratch → Hann window → FFT →
   * magnitude → 48 log bands → temporal EMA smoothing → AGC normalization →
   * latestBands. All scratch buffers come from `entry` — zero allocations
   * per frame. The window was already copied from the ring by readRingWindow.
   */
  private computeBandsInto(
    entry: {
      windowScratch: Float32Array;
      hann: Float64Array;
      twiddle: Float64Array;
      bitReversal: Uint32Array;
      bandEdges: number[];
      re: Float64Array;
      im: Float64Array;
      mag: Float64Array;
      bandSmooth: Float64Array;
      agcPeak: number;
      latestBands: number[] | null;
    },
  ): void {
    const n = SpectrumService.FFT_SIZE;
    const { re, im, mag, bandSmooth, windowScratch } = entry;

    // 1. Read samples from the window scratch buffer and apply Hann window.
    for (let i = 0; i < n; i++) {
      re[i] = windowScratch[i] * entry.hann[i];
      im[i] = 0;
    }

    // 2. Radix-2 iterative Cooley-Tukey FFT (in-place on re/im).
    this.fftInPlace(re, im, entry.bitReversal, entry.twiddle, n);

    // 3. Magnitude spectrum for the first N/2 bins (Nyquist).
    for (let i = 0; i < n / 2; i++) {
      mag[i] = Math.sqrt(re[i] * re[i] + im[i] * im[i]);
    }

    // 4. Aggregate into 48 log-spaced bands (every band ≥ 1 bin wide),
    //    then apply temporal EMA smoothing to kill periodogram variance.
    const alpha = SpectrumService.EMA_ALPHA;
    for (let b = 0; b < SpectrumService.BAND_COUNT; b++) {
      const lo = entry.bandEdges[b];
      const hi = Math.max(lo + 1, entry.bandEdges[b + 1]);
      let sum = 0;
      let count = 0;
      for (let i = lo; i < hi && i < n / 2; i++) {
        sum += mag[i];
        count++;
      }
      const avg = count > 0 ? sum / count : 0;
      const scaled = Math.log10(avg + 1) / Math.log10(n / 2 + 1);

      bandSmooth[b] = bandSmooth[b] * (1 - alpha) + scaled * alpha;
    }

    // 5. AGC: track the running peak across bands and normalize so the
    //    visualizer stays lively regardless of station loudness.
    let framePeak = 0;
    for (let b = 0; b < SpectrumService.BAND_COUNT; b++) {
      if (bandSmooth[b] > framePeak) framePeak = bandSmooth[b];
    }
    entry.agcPeak = Math.max(
      framePeak,
      entry.agcPeak * SpectrumService.AGC_DECAY,
      SpectrumService.AGC_FLOOR,
    );

    // 6. Emit normalized 0..1 values into the reused latestBands array.
    if (!entry.latestBands)
      entry.latestBands = new Array(SpectrumService.BAND_COUNT);
    const out = entry.latestBands;
    for (let b = 0; b < SpectrumService.BAND_COUNT; b++) {
      out[b] = Math.min(1, Math.max(0, bandSmooth[b] / entry.agcPeak));
    }
  }

  /** In-place radix-2 iterative Cooley-Tukey FFT. */
  private fftInPlace(
    re: Float64Array,
    im: Float64Array,
    bitRev: Uint32Array,
    twiddle: Float64Array,
    n: number,
  ): void {
    // Bit-reversal permutation.
    for (let i = 0; i < n; i++) {
      const j = bitRev[i];
      if (j > i) {
        [re[i], re[j]] = [re[j], re[i]];
        [im[i], im[j]] = [im[j], im[i]];
      }
    }

    // Butterfly stages.
    for (let size = 2; size <= n; size *= 2) {
      const half = size / 2;
      const step = n / size;
      for (let i = 0; i < n; i += size) {
        for (let j = i, k = 0; j < i + half; j++, k += step) {
          const twIdx = k * 2; // twiddle stores [cos, sin] interleaved
          const cos = twiddle[twIdx];
          const sin = twiddle[twIdx + 1];
          const reIdx = re[j + half];
          const imIdx = im[j + half];
          const tRe = reIdx * cos - imIdx * sin;
          const tIm = reIdx * sin + imIdx * cos;
          re[j + half] = re[j] - tRe;
          im[j + half] = im[j] - tIm;
          re[j] += tRe;
          im[j] += tIm;
        }
      }
    }
  }

  // ── Precomputation helpers ──────────────────────────────────────────────

  private precomputeHann(n: number): Float64Array {
    const w = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (n - 1)));
    }
    return w;
  }

  /** Interleaved [cos0, sin0, cos1, sin1, ...] twiddle factors for size n. */
  private precomputeTwiddle(n: number): Float64Array {
    const tw = new Float64Array(n); // n/2 complex pairs → n floats
    for (let i = 0; i < n / 2; i++) {
      const angle = (-2 * Math.PI * i) / n;
      tw[i * 2] = Math.cos(angle);
      tw[i * 2 + 1] = Math.sin(angle);
    }
    return tw;
  }

  private precomputeBitReversal(n: number): Uint32Array {
    const rev = new Uint32Array(n);
    const bits = Math.log2(n);
    for (let i = 0; i < n; i++) {
      let r = 0;
      for (let j = 0; j < bits; j++) {
        if (i & (1 << j)) r |= 1 << (bits - 1 - j);
      }
      rev[i] = r;
    }
    return rev;
  }

  /**
   * Compute the bin-index edges for `bandCount` log-spaced frequency bands
   * between `minFreq` and `maxFreq`, given the sample rate and FFT size.
   * Returns `bandCount + 1` edges (inclusive lower, exclusive upper).
   */
  private computeBandEdges(
    bandCount: number,
    minFreq: number,
    maxFreq: number,
    sampleRate: number,
    fftSize: number,
  ): number[] {
    const binHz = sampleRate / fftSize; // Hz per FFT bin
    const edges: number[] = [];
    for (let b = 0; b <= bandCount; b++) {
      const freq = minFreq * Math.pow(maxFreq / minFreq, b / bandCount);
      edges.push(Math.max(0, Math.min(fftSize / 2, Math.round(freq / binHz))));
    }
    return edges;
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────

  private cleanupStream(url: string): void {
    const entry = this.streams.get(url);
    if (!entry) return;

    if (entry.pushTimer) {
      clearInterval(entry.pushTimer);
    }
    try {
      if (!entry.proc.killed) {
        entry.proc.kill('SIGTERM');
      }
    } catch {
      // process may have already exited
    }

    // Remove listenerId mappings for this URL.
    for (const [listenerId, u] of this.listenerUrls) {
      if (u === url) this.listenerUrls.delete(listenerId);
    }

    this.streams.delete(url);
  }
}


