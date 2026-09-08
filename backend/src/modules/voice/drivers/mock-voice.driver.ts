import { VoiceDriver, VoiceAvailability } from './voice.driver';

/**
 * Simulated voice driver (default): deterministic, no microphone, no models.
 *
 * - `transcribe` ignores the audio and returns a canned command (cyclical) so
 *   the whole pipeline (REST → intent → reply) is exercised end-to-end in dev
 *   and tests without hardware.
 * - `speak` returns a tiny valid WAV (a short sine "beep") so the UI has real
 *   bytes to play through the normal audio path.
 */
export class MockVoiceDriver extends VoiceDriver {
  readonly kind = 'mock';

  /** Canned commands cycled on each transcribe() call. */
  private readonly canned = [
    'qué tiempo hace',
    'pon música',
    'llévame a Bilbao',
    'sube el volumen',
  ];
  private index = 0;

  /** Injectable scripted utterances for tests; falls back to the canned list. */
  public script: string[] | null = null;
  private scriptIndex = 0;

  async availability(): Promise<VoiceAvailability> {
    return { asr: true, tts: true, note: 'Simulado (sin micrófono real)' };
  }

  async transcribe(_pcm: Buffer): Promise<string> {
    if (this.script && this.script.length > 0) {
      const out = this.script[this.scriptIndex % this.script.length];
      this.scriptIndex++;
      return out;
    }
    const out = this.canned[this.index % this.canned.length];
    this.index++;
    return out;
  }

  async speak(text: string): Promise<Buffer> {
    return MockVoiceDriver.beepWav(Math.min(1 + text.length * 0.01, 2.5));
  }

  /**
   * Build a minimal valid 16-bit mono WAV of a 660 Hz sine beep of `seconds`.
   * 16 kHz sample rate to match the ASR pipeline. Deterministic.
   */
  static beepWav(seconds = 1): Buffer {
    const rate = 16000;
    const n = Math.max(1, Math.floor(rate * seconds));
    const data = Buffer.alloc(n * 2);
    for (let i = 0; i < n; i++) {
      // Fade in/out to avoid clicks.
      const env = Math.min(1, Math.min(i, n - i) / (rate * 0.02));
      const s = Math.sin((2 * Math.PI * 660 * i) / rate) * 0.3 * env;
      data.writeInt16LE(Math.round(s * 32767), i * 2);
    }
    const header = Buffer.alloc(44);
    header.write('RIFF', 0);
    header.writeUInt32LE(36 + data.length, 4);
    header.write('WAVE', 8);
    header.write('fmt ', 12);
    header.writeUInt32LE(16, 16); // PCM chunk size
    header.writeUInt16LE(1, 20); // PCM format
    header.writeUInt16LE(1, 22); // mono
    header.writeUInt32LE(rate, 24);
    header.writeUInt32LE(rate * 2, 28); // byte rate
    header.writeUInt16LE(2, 32); // block align
    header.writeUInt16LE(16, 34); // bits
    header.write('data', 36);
    header.writeUInt32LE(data.length, 40);
    return Buffer.concat([header, data]);
  }
}
