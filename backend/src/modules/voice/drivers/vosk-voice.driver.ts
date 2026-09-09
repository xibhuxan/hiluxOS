import { join } from 'node:path';
import { CommandRunner } from '../../system/command-runner';
import { VoiceDriver, VoiceAvailability } from './voice.driver';

/**
 * Real offline voice stack: Vosk (ASR) + Piper (TTS), both local.
 *
 * Strategy (best-effort, degrades gracefully like RpiPowerDriver):
 *  - Availability: a Vosk Spanish model exists under `VOSK_MODEL` (or the
 *    default path) and a Piper binary + voice are present.
 *  - ASR: pipes 16 kHz mono PCM to a small Python helper (`vosk_transcribe`)
 *    that loads the model once per utterance. On the Pi this can be swapped for
 *    a long-lived streaming recogniser; the REST/WS contract is unchanged.
 *  - TTS: runs `piper` with the configured voice, reading the WAV from stdout.
 *
 * ⚠️  REQUIRES VALIDATION ON REAL HARDWARE (Raspberry Pi + mic). The exact
 * binaries/paths vary; anything missing degrades `availability()` to
 * asr/tts:false so the UI can show "Voz no disponible" instead of crashing.
 */
export class VoskVoiceDriver extends VoiceDriver {
  readonly kind = 'vosk';

  /**
   * Path to the capture helper script. Works whether the driver runs from
   * `src/modules/voice/drivers` (ts-node) or `dist/modules/voice/drivers`
   * (compiled): walk up to the `backend/` dir, then into `src/`.
   */
  private static readonly CAPTURE_SCRIPT = join(
    __dirname, '..', '..', '..', '..', 'src', 'modules', 'voice', 'drivers', 'vosk_capture.py',
  );

  constructor(
    private readonly cmd: CommandRunner,
    private readonly modelPath = process.env.VOSK_MODEL ?? '/home/xibhu/.hiluxos/models/vosk-es',
    /** Python with vosk + sounddevice installed (the project venv). */
    private readonly pythonBin = process.env.VOICE_PYTHON ?? '/home/xibhu/.hiluxos-venv/bin/python',
    private readonly piperBin = process.env.PIPER_BIN ?? '/home/xibhu/.hiluxos/models/piper/piper/piper',
    private readonly piperVoice = process.env.PIPER_VOICE ?? '/home/xibhu/.hiluxos/models/piper_voices/es_ES-sharvard-medium.onnx',
  ) {
    super();
  }

  async availability(): Promise<VoiceAvailability> {
    // A model directory + a capture device → ASR. A piper binary + voice → TTS.
    const asrModel = this.cmd.run('test', ['-d', this.modelPath]) !== null;
    const hasMic = this.cmd.run('sh', ['-c', 'arecord -l 2>/dev/null | grep -q "card"']) !== null;
    const python = this.cmd.run('test', ['-x', this.pythonBin]) !== null;
    const asr = asrModel && hasMic && python;

    const piper = this.cmd.run('sh', ['-c', `command -v ${this.piperBin} 2>/dev/null`]) !== null;
    const voice = this.cmd.run('test', ['-f', this.piperVoice]) !== null;
    const tts = piper && voice;

    const note = !asr && !tts
      ? 'Ni Vosk ni Piper están disponibles'
      : !asr
        ? 'ASR no disponible (falta modelo, micrófono o el venv de Python)'
        : !tts
          ? 'TTS no disponible (falta Piper o voz)'
          : null;
    return { asr, tts, note };
  }

  /**
   * Capture a few seconds from the real microphone with sounddevice and
   * transcribe with Vosk. The `pcm` argument is ignored on the real driver
   * (audio comes from the mic, not the caller); it exists to satisfy the
   * VoiceDriver contract the mock uses in tests. Best-effort: any failure →
   * empty string ("no oído").
   */
  async transcribe(_pcm: Buffer): Promise<string> {
    try {
      const seconds = (process.env.VOICE_LISTEN_SECONDS ?? '4').toString();
      const out = this.cmd.runOrThrow(
        this.pythonBin,
        [VoskVoiceDriver.CAPTURE_SCRIPT, this.modelPath, seconds],
        30000, // model load (cold) + capture window + transcription
      );
      return (out ?? '').trim();
    } catch {
      return '';
    }
  }

  async speak(text: string): Promise<Buffer> {
    try {
      const out = this.cmd.runOrThrow(
        this.piperBin,
        ['--model', this.piperVoice, '--output-raw', '--stdin'],
        15000,
        text,
      );
      // Piper --output-raw emits raw PCM; wrap in a WAV header (22.05 kHz mono).
      const pcm = Buffer.from(out, 'binary');
      return VoskVoiceDriver.wrapWav(pcm, 22050);
    } catch {
      // Fall back to a short silence so the UI still gets playable bytes.
      return VoskVoiceDriver.wrapWav(Buffer.alloc(22050), 22050);
    }
  }

  /** Wrap raw 16-bit mono PCM in a minimal WAV header. */
  static wrapWav(pcm: Buffer, rate: number): Buffer {
    const header = Buffer.alloc(44);
    header.write('RIFF', 0);
    header.writeUInt32LE(36 + pcm.length, 4);
    header.write('WAVE', 8);
    header.write('fmt ', 12);
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20);
    header.writeUInt16LE(1, 22);
    header.writeUInt32LE(rate, 24);
    header.writeUInt32LE(rate * 2, 28);
    header.writeUInt16LE(2, 32);
    header.writeUInt16LE(16, 34);
    header.write('data', 36);
    header.writeUInt32LE(pcm.length, 40);
    return Buffer.concat([header, pcm]);
  }
}
