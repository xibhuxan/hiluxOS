/**
 * Voice HAL — driver interface for the speech pipeline.
 *
 * The assistant has three hardware-ish concerns, all behind this abstraction so
 * the service/controller layers stay pure and testable (ARCHITECTURE.md):
 *
 *   - **ASR** (speech → text): Vosk offline model on the Pi; a mock elsewhere.
 *   - **TTS** (text → speech): Piper offline voice on the Pi; the mock returns
 *     a tone/silence WAV so the UI can still play something.
 *   - **Availability**: whether a capture device + models exist.
 *
 * Substitution chain: MockVoiceDriver (default, deterministic, no I/O) →
 * VoskVoiceDriver (spawns a local Python helper / shells out to piper).
 * Selection by env: `VOICE_DRIVER=mock|vosk`.
 */

/** Whether the voice stack can run on this machine. */
export interface VoiceAvailability {
  /** ASR engine ready (model + capture device present). */
  asr: boolean;
  /** TTS engine ready (voice model present). */
  tts: boolean;
  /** Human-readable note when something is unavailable. */
  note: string | null;
}

/**
 * Abstract voice driver. Implementations keep their own state (loaded model,
 * open stream) so calls are cheap. `transcribe` consumes a chunk of PCM audio;
 * `speak` synthesises text into a WAV buffer.
 */
export abstract class VoiceDriver {
  abstract readonly kind: string;

  /** Is the voice stack usable here? Cheap, cached where possible. */
  abstract availability(): Promise<VoiceAvailability>;

  /**
   * Transcribe 16-bit mono PCM (16 kHz) to text. Returns the recognised
   * utterance (empty string when nothing intelligible was said).
   */
  abstract transcribe(pcm: Buffer): Promise<string>;

  /**
   * Synthesise Spanish text to a WAV buffer (16-bit mono). The mock returns a
   * short silence/tone; the real driver shells out to Piper.
   */
  abstract speak(text: string): Promise<Buffer>;
}
