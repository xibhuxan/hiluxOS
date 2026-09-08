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

  constructor(
    private readonly cmd: CommandRunner,
    private readonly modelPath = process.env.VOSK_MODEL ?? '/opt/hiluxos/models/vosk-es',
    private readonly piperBin = process.env.PIPER_BIN ?? 'piper',
    private readonly piperVoice = process.env.PIPER_VOICE ?? '/opt/hiluxos/models/piper/es_ES.onnx',
  ) {
    super();
  }

  async availability(): Promise<VoiceAvailability> {
    // A model directory + a capture device → ASR. A piper binary + voice → TTS.
    const asrModel = this.cmd.run('test', ['-d', this.modelPath]) !== null ||
      this.cmd.run('sh', ['-c', `test -d ${this.modelPath}`]) !== null;
    const hasMic = this.cmd.run('sh', ['-c', 'arecord -l | grep -q "card"']) !== null;
    const asr = asrModel && hasMic;

    const piper = this.cmd.run('sh', ['-c', `command -v ${this.piperBin}`]) !== null;
    const voice = this.cmd.run('sh', ['-c', `test -f ${this.piperVoice}`]) !== null;
    const tts = piper && voice;

    const note = !asr && !tts
      ? 'Ni Vosk ni Piper están disponibles'
      : !asr
        ? 'ASR no disponible (falta modelo o micrófono)'
        : !tts
          ? 'TTS no disponible (falta Piper o voz)'
          : null;
    return { asr, tts, note };
  }

  async transcribe(pcm: Buffer): Promise<string> {
    // Pipe the PCM to a Vosk helper. The helper prints the recognised text on
    // stdout. Best-effort: any failure → empty string (treated as "no oído").
    try {
      const out = this.cmd.runOrThrow(
        'vosk_transcribe',
        ['--model', this.modelPath],
        15000,
        pcm.toString('base64'), // helper decodes base64 PCM on stdin
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
