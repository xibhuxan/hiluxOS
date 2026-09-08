import { BtMediaDriver, BtMediaState, BtMediaStatus, BtTrack, clampBtVolume } from './btmedia.driver';

/** One entry of the simulated phone playlist. */
interface PlaylistEntry {
  title: string;
  artist: string;
  album: string;
  durationSec: number;
}

/**
 * Simulated Bluetooth media source (default driver): a paired phone streaming
 * over A2DP with a fixed in-memory playlist. Deterministic and free of I/O.
 *
 * Position is a pure function of an injectable clock (same approach as
 * MockVehicleDriver): while playing, `positionSec = anchor + (now - startedAt)`,
 * wrapped at the track duration (which auto-advances to the next track). No
 * timers, no randomness → deterministic and testable.
 */
export class MockBtMediaDriver extends BtMediaDriver {
  readonly kind = 'mock';

  private readonly clock: () => number;

  /** The simulated phone's playlist. */
  private readonly playlist: PlaylistEntry[] = [
    { title: 'Highway to Hell', artist: 'AC/DC', album: 'Highway to Hell', durationSec: 208 },
    { title: 'Radar Love', artist: 'Golden Earring', album: 'Moontan', durationSec: 382 },
    { title: 'Life Is a Highway', artist: 'Tom Cochrane', album: 'Mad Mad World', durationSec: 266 },
    { title: 'Born to Run', artist: 'Bruce Springsteen', album: 'Born to Run', durationSec: 270 },
    { title: 'Drive', artist: 'The Cars', album: 'Heartbeat City', durationSec: 225 },
  ];

  private index = 0;
  private status: BtMediaStatus = 'paused';
  private volume = 0.7;

  /** Position (sec) at `startedAtMs`. */
  private anchorSec = 0;
  /** Clock reading when the current playing segment started. */
  private startedAtMs: number;

  /** `clock` is injectable so tests can fast-forward time deterministically. */
  constructor(clock: () => number = Date.now) {
    super();
    this.clock = clock;
    this.startedAtMs = clock();
  }

  getState(): BtMediaState {
    // Fold elapsed time into the anchor so auto-advance is committed.
    this.syncPosition();
    const entry = this.playlist[this.index];
    const track: BtTrack = {
      title: entry.title,
      artist: entry.artist,
      album: entry.album,
      durationSec: entry.durationSec,
      positionSec: Math.floor(this.anchorSec),
    };
    return {
      available: true,
      connected: true,
      deviceName: 'Pixel 8 Pro',
      track,
      status: this.status,
      volume: this.volume,
    };
  }

  play(): BtMediaState {
    if (this.status !== 'playing') {
      this.startedAtMs = this.clock();
      this.status = 'playing';
    }
    return this.getState();
  }

  pause(): BtMediaState {
    if (this.status === 'playing') {
      this.syncPosition(); // freeze the anchor at the current position
      this.status = 'paused';
    }
    return this.getState();
  }

  next(): BtMediaState {
    this.index = (this.index + 1) % this.playlist.length;
    this.restartPosition();
    return this.getState();
  }

  previous(): BtMediaState {
    // Like most head units: if we're a few seconds in, restart the current
    // track; otherwise go to the previous one.
    this.syncPosition();
    if (this.anchorSec > 3) {
      this.restartPosition();
    } else {
      this.index = (this.index - 1 + this.playlist.length) % this.playlist.length;
      this.restartPosition();
    }
    return this.getState();
  }

  setVolume(volume: number): BtMediaState {
    this.volume = clampBtVolume(volume);
    return this.getState();
  }

  // ---- position bookkeeping ----

  /** Commit elapsed playing time into the anchor, auto-advancing on track end. */
  private syncPosition(): void {
    if (this.status !== 'playing') return;
    const elapsed = (this.clock() - this.startedAtMs) / 1000;
    let pos = this.anchorSec + elapsed;
    const dur = this.playlist[this.index].durationSec;
    // Auto-advance (possibly several tracks) when a track finishes.
    while (pos >= dur && dur > 0) {
      pos -= dur;
      this.index = (this.index + 1) % this.playlist.length;
    }
    this.anchorSec = pos;
    this.startedAtMs = this.clock();
  }

  /** Reset the position to 0 for the (new) current track. */
  private restartPosition(): void {
    this.anchorSec = 0;
    this.startedAtMs = this.clock();
  }
}
