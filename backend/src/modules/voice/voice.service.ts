import { Inject, Injectable, Logger } from '@nestjs/common';
import { VoiceDriver, VoiceAvailability } from './drivers/voice.driver';
import { parseIntent, VoiceIntent } from './intent';
import { EventsGateway } from '../events/events.gateway';

/** DI token for the substituted driver (bound in voice.module.ts). */
export const VOICE_DRIVER = Symbol('VOICE_DRIVER');

/** One turn of the conversation (user utterance + assistant reply). */
export interface VoiceTurn {
  /** What the user said / typed. */
  utterance: string;
  /** The parsed intent kind. */
  intent: string;
  /** The assistant's spoken reply. */
  reply: string;
  /** Whether the intent was confident enough to act on. */
  acted: boolean;
  /** Epoch ms when the turn happened. */
  at: number;
}

/** The assistant's public state (status + recent conversation). */
export interface VoiceState {
  /** Whether the pipeline is idle/listening/thinking/speaking. */
  status: 'idle' | 'listening' | 'thinking' | 'speaking';
  /** Whether ASR/TTS are usable on this machine. */
  availability: VoiceAvailability;
  /** The recent conversation, most recent last (capped). */
  history: VoiceTurn[];
}

const HISTORY_CAP = 50;
/** Below this confidence the assistant asks for clarification instead of acting. */
const ACT_THRESHOLD = 0.5;

/**
 * Voice assistant service: orchestrates driver (ASR/TTS) + intent engine and
 * keeps a short conversation history. Stateless-ish — the only state is the
 * history and the current status, both cheap.
 *
 * Hardware-free: all mic/model interaction lives behind the injected
 * VoiceDriver, so this class is fully unit-testable with the mock.
 */
@Injectable()
export class VoiceService {
  private readonly logger = new Logger(VoiceService.name);
  private history: VoiceTurn[] = [];
  private status: VoiceState['status'] = 'idle';

  constructor(
    @Inject(VOICE_DRIVER) private readonly driver: VoiceDriver,
    private readonly events: EventsGateway,
  ) {}

  /** The assistant's current public state. */
  async getState(): Promise<VoiceState> {
    return {
      status: this.status,
      availability: await this.driver.availability(),
      history: [...this.history],
    };
  }

  /** The recent conversation. */
  getHistory(): VoiceTurn[] {
    return [...this.history];
  }

  /** Clear the conversation history. */
  clearHistory(): void {
    this.history = [];
  }

  /**
   * Handle a *text* command (typed, or from a test). Runs the same intent
   * pipeline as a spoken command. Emits `voice` events over WebSocket.
   */
  async handleTextCommand(text: string): Promise<VoiceTurn> {
    this.setStatus('thinking');
    const intent = parseIntent(text);
    const turn = this.record(text, intent);
    this.setStatus('idle');
    return turn;
  }

  /**
   * Handle a *spoken* command: transcribe the PCM via the driver, then run the
   * intent pipeline on the recognised text.
   */
  async handleAudioCommand(pcm: Buffer): Promise<VoiceTurn> {
    this.setStatus('listening');
    const utterance = await this.driver.transcribe(pcm);
    this.setStatus('thinking');
    const intent = parseIntent(utterance);
    const turn = this.record(utterance || '(inaudible)', intent);
    this.setStatus('idle');
    return turn;
  }

  /** Synthesise text to a WAV buffer via the driver. */
  async speak(text: string): Promise<Buffer> {
    this.setStatus('speaking');
    try {
      return await this.driver.speak(text);
    } finally {
      this.setStatus('idle');
    }
  }

  // ---- internals ----

  private record(utterance: string, intent: VoiceIntent): VoiceTurn {
    const turn: VoiceTurn = {
      utterance,
      intent: intent.kind,
      reply: intent.reply,
      acted: intent.confidence >= ACT_THRESHOLD && intent.kind !== 'unknown',
      at: Date.now(),
    };
    this.history.push(turn);
    if (this.history.length > HISTORY_CAP) this.history.shift();
    // Notify live clients (the UI updates its conversation view).
    this.events.broadcast('voice', turn);
    return turn;
  }

  private setStatus(status: VoiceState['status']): void {
    this.status = status;
    this.events.broadcast('voice_status', { status });
  }
}
