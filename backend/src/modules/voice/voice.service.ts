import { Inject, Injectable, Logger } from '@nestjs/common';
import { VoiceDriver, VoiceAvailability } from './drivers/voice.driver';
import { parseIntent, VoiceIntent } from './intent';
import { OllamaService, OllamaMessage } from './ollama.service';
import { AssistantToolsService } from './assistant-tools.service';
import { EventsGateway } from '../events/events.gateway';
import { RadioService, StationDto } from '../radio/radio.service';
import { SystemService } from '../system/system.service';
import { BtMediaService } from '../btmedia/btmedia.service';
import { WeatherService } from '../weather/weather.service';

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
  /** A UI action the app should run (open a screen, offer stations, …). */
  action?: VoiceUiAction;
}

/** A UI hint the app can act on (open a screen, offer a station picker, …). */
export interface VoiceUiAction {
  /** The action name: 'open_radio' | 'open_media' | 'open_nav' | 'choose_station'. */
  type: string;
  /** Candidate stations to pick from (for 'choose_station'). */
  stations?: StationDto[];
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
/** Volume step (percentage points) for "sube/baja el volumen". */
const VOLUME_STEP = 10;

/**
 * Voice assistant service: orchestrates driver (ASR/TTS) + intent engine,
 * executes the recognised intent against the real modules (radio catalogue,
 * master volume, Bluetooth media, weather) and keeps a short conversation
 * history.
 *
 * Radio playback itself happens on the device (Flutter's AudioPlayer) — the
 * backend only resolves the station and broadcasts a `voice_action` event so
 * the app plays it. Everything else (volume, weather, BT media) the backend
 * executes directly.
 */
@Injectable()
export class VoiceService {
  private readonly logger = new Logger(VoiceService.name);
  private history: VoiceTurn[] = [];
  private status: VoiceState['status'] = 'idle';

  constructor(
    @Inject(VOICE_DRIVER) private readonly driver: VoiceDriver,
    private readonly events: EventsGateway,
    private readonly radio: RadioService,
    private readonly system: SystemService,
    private readonly btmedia: BtMediaService,
    private readonly weather: WeatherService,
    private readonly ollama: OllamaService,
    private readonly tools: AssistantToolsService,
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

  private async record(utterance: string, intent: VoiceIntent): Promise<VoiceTurn> {
    let acted = intent.confidence >= ACT_THRESHOLD && intent.kind !== 'unknown';
    let reply = intent.reply;
    let action: VoiceUiAction | undefined;
    let kind: string = intent.kind;

    if (acted) {
      // Fast path: the deterministic parser recognised the command — execute
      // it directly against the real modules (radio, volume, weather, …).
      const result = await this.execute(intent);
      reply = result.reply;
      action = result.action;
    } else {
      // The regex brain didn't understand. Fall back to the LLM (Ollama) which
      // can reason, chat and call tools across every module. If Ollama isn't
      // available we keep the parser's clarification reply.
      const llm = await this.runLlm(utterance);
      if (llm) {
        reply = llm.reply;
        action = llm.action;
        acted = llm.acted;
        kind = llm.kind;
      }
    }

    const turn: VoiceTurn = {
      utterance,
      intent: kind,
      reply,
      acted,
      at: Date.now(),
      ...(action ? { action } : {}),
    };
    this.history.push(turn);
    if (this.history.length > HISTORY_CAP) this.history.shift();
    // Notify live clients (the UI updates its conversation view).
    this.events.broadcast('voice', turn);
    return turn;
  }

  // ---- LLM brain (Ollama) ----

  /**
   * The system prompt that turns the model into the hiluxOS assistant. The
   * caller injects the user's favourite radio stations so the model can map a
   * spoken name ("la de anime", "rock") to the real station without a brittle
   * substring match.
   */
  private systemPrompt(stations: string[]): string {
    const stationLine = stations.length > 0
      ? `Las emisoras favoritas del usuario son: ${stations.join(', ')}. Cuando pida la radio por nombre o descripción (p. ej. "la de anime", "rock", "los 40"), identifica cuál de estas favoritas encaja y llama a radio_play con el nombre EXACTO de esa emisora; si ninguna encaja claramente, llama a radio_play con el término que dijo para buscarla. `
      : 'El usuario no tiene emisoras favoritas guardadas; si pide una por nombre, llama a radio_play con ese nombre para buscarla en el catálogo. ';
    return (
      'Eres Hilux, el asistente de voz de un coche (hiluxOS), integrado en el salpicadero. ' +
      'Respondes SIEMPRE en español, de forma muy breve y natural (1-2 frases), pensada para escuchar, no para leer. ' +
      stationLine +
      'Tienes herramientas (tools) para ACTUAR sobre el coche y el sistema: radio, volumen, clima, música Bluetooth, ' +
      'recordatorios/tareas, luces/puertas/ventanillas del vehículo, estado del sistema y abrir pantallas. ' +
      'REGLA ESTRICTA: cuando el usuario pida una acción (poner/quitar radio, subir volumen, añadir o listar ' +
      'recordatorios, encender luces, abrir una pantalla, el tiempo, etc.) DEBES llamar a la herramienta ' +
      'correspondiente. NUNCA afirmes que has hecho algo sin haber llamado antes a su herramienta: la acción solo ' +
      'ocurre de verdad mediante la tool. ' +
      'Cuando la herramienta devuelva el resultado, confírmalo en una frase breve basándote en ese resultado. ' +
      'Si te piden varias cosas, llama a varias herramientas. ' +
      'Solo si es una pregunta o charla que no requiere actuar sobre el sistema responde directamente, sin tools. ' +
      'Si te preguntan qué modelo de IA eres, contesta que eres Hilux, el asistente del coche. ' +
      'No inventes datos: si no sabes algo, dilo. Nunca respondas con JSON ni listas con viñetas.'
    );
  }

  /**
   * Run the LLM fallback with tool-calling. Returns the reply + optional UI
   * action, or null when Ollama is unavailable/errors (caller keeps the
   * parser's clarification reply). Maintains a short rolling context.
   */
  private async runLlm(utterance: string): Promise<{ reply: string; action?: VoiceUiAction; acted: boolean; kind: string } | null> {
    if (!(await this.ollama.isAvailable())) return null;
    try {
      // Give the model the user's favourite stations so it can map a spoken
      // name to the real one (the whole point of "ponme la de anime").
      let stationNames: string[] = [];
      try {
        stationNames = ((await this.radio.listFavorites()) ?? []).map((s) => s.name);
      } catch { /* favourites are best-effort context */ }

      // Build the conversation: system + recent history + this utterance.
      const messages: OllamaMessage[] = [{ role: 'system', content: this.systemPrompt(stationNames) }];
      for (const t of this.history.slice(-8)) {
        messages.push({ role: 'user', content: t.utterance });
        messages.push({ role: 'assistant', content: t.reply });
      }
      messages.push({ role: 'user', content: utterance });

      let action: VoiceUiAction | undefined;
      let acted = false;
      let usedTool: string | null = null;

      // Tool-calling loop: the model may call tools, we feed results back. A
      // round with no tool calls and empty content is retried (small models
      // occasionally return an empty message) rather than aborting.
      for (let round = 0; round < 4; round++) {
        const msg = await this.ollama.chat(messages, this.tools.tools);
        const calls = msg.tool_calls ?? [];
        if (calls.length === 0) {
          const reply = (msg.content ?? '').trim();
          if (reply) return { reply, action, acted, kind: usedTool ?? 'chat' };
          if (acted) break; // tools ran but the model went quiet → summarise below
          continue; // empty & nothing acted → retry
        }
        // Record the assistant turn with its tool calls, then run each tool.
        messages.push({ role: 'assistant', content: msg.content ?? '', tool_calls: calls });
        for (const call of calls) {
          const fn = call.function?.name ?? '';
          const args = call.function?.arguments ?? {};
          const result = await this.tools.run(fn, args);
          usedTool = fn;
          acted = true;
          if (result.action) action = result.action as VoiceUiAction;
          messages.push({ role: 'tool', tool_name: fn, content: result.text });
        }
      }

      // Rounds exhausted (or the model went quiet after acting): ask for a
      // final confirmation WITHOUT offering tools so it just summarises what
      // happened. Guaranteed to produce a reply when tools ran.
      const finalMessages: OllamaMessage[] = acted
        ? [...messages, { role: 'user', content: 'Confirma en una frase breve lo que acabas de hacer.' }]
        : messages;
      const finalMsg = await this.ollama.chat(finalMessages);
      const reply = (finalMsg.content ?? '').trim();
      return reply ? { reply, action, acted, kind: usedTool ?? 'chat' } : null;
    } catch (err) {
      this.logger.warn(`LLM fallback failed: ${(err as Error).message}`);
      return null;
    }
  }

  /**
   * Execute a confident intent against the real modules and return the outcome
   * to speak. Best-effort: a failing module produces a spoken apology rather
   * than an exception, so the assistant always answers.
   */
  private async execute(intent: VoiceIntent): Promise<{ reply: string; action?: VoiceUiAction }> {
    try {
      switch (intent.kind) {
        case 'volume':
          return { reply: this.execVolume(intent) };
        case 'media_control':
          return this.execMedia(intent);
        case 'radio':
          return await this.execRadio(intent);
        case 'weather':
          return { reply: await this.execWeatherCurrent(intent) };
        case 'weather_forecast':
          return { reply: await this.execWeatherForecast(intent) };
        case 'system_status':
          return { reply: this.execSystemStatus() };
        default:
          // navigate / call / climate / help: no backend execution — the intent's
          // own reply stands (navigation opens on the app side).
          return { reply: intent.reply };
      }
    } catch (err) {
      this.logger.warn(`Intent ${intent.kind} execution failed: ${err}`);
      return { reply: 'Lo siento, no he podido hacerlo ahora mismo.' };
    }
  }

  // ---- volume (master sink via wpctl/amixer) ----

  private execVolume(intent: VoiceIntent): string {
    const action = intent.entities.action;
    if (action === 'mute') {
      this.system.setAudioMuted(true);
      return 'Silenciando.';
    }
    const current = this.system.getAudio().volume;
    if (typeof intent.entities.level === 'number') {
      const level = Math.max(0, Math.min(100, Math.round(intent.entities.level)));
      this.system.setAudioVolume(level);
      return `Volumen al ${level} por ciento.`;
    }
    if (action === 'up' || action === 'down') {
      const base = current ?? 50;
      const next =
        action === 'up'
          ? Math.min(100, base + VOLUME_STEP)
          : Math.max(0, base - VOLUME_STEP);
      this.system.setAudioVolume(next);
      return `Volumen al ${next} por ciento.`;
    }
    return '¿Qué hago con el volumen?';
  }

  // ---- Bluetooth media transport ----

  private execMedia(intent: VoiceIntent): { reply: string; action?: VoiceUiAction } {
    const state = this.btmedia.getState();
    if (!state.connected) {
      return { reply: 'No hay ningún dispositivo Bluetooth conectado.' };
    }
    switch (intent.entities.action) {
      case 'play':
        this.btmedia.play();
        return { reply: 'Reproduciendo.' };
      case 'pause':
        this.btmedia.pause();
        return { reply: 'Pausando la música.' };
      case 'next':
        this.btmedia.next();
        return { reply: 'Siguiente canción.' };
      case 'previous':
        this.btmedia.previous();
        return { reply: 'Canción anterior.' };
      case 'stop':
        this.btmedia.pause();
        return { reply: 'Música detenida.' };
      default:
        this.btmedia.play();
        return { reply: 'Reproduciendo.' };
    }
  }

  // ---- radio (catalogue + playback delegated to the app) ----

  private async execRadio(intent: VoiceIntent): Promise<{ reply: string; action?: VoiceUiAction }> {
    const { station, action } = intent.entities as { station?: string; action?: string };

    if (action === 'stop') {
      this.events.broadcast('voice_action', { type: 'radio_stop' });
      return { reply: 'Apagando la radio.' };
    }

    if (action === 'list') {
      const favs = (await this.radio.listFavorites()) ?? [];
      if (favs.length === 0) {
        return { reply: 'No tienes emisoras favoritas todavía. Añade alguna desde la pantalla de radio.' };
      }
      const names = favs.slice(0, 5).map((s) => s.name).join(', ');
      const extra = favs.length > 5 ? ` y ${favs.length - 5} más` : '';
      return {
        reply: `Tienes ${favs.length} favoritas: ${names}${extra}.`,
        action: { type: 'choose_station', stations: favs },
      };
    }

    if (station) {
      return this.playStationByName(station);
    }

    // Bare "pon la radio": resume the most recent station, else first favorite.
    const [history, favs] = await Promise.all([
      this.radio.listHistory(1),
      this.radio.listFavorites(),
    ]);
    const candidate = (history ?? [])[0] ?? (favs ?? [])[0];
    if (candidate) {
      this.playStation(candidate);
      return { reply: `Encendiendo la radio con ${candidate.name}.`, action: { type: 'open_radio' } };
    }
    return {
      reply: 'No tienes emisoras guardadas. Dime una, por ejemplo: pon Los 40.',
      action: { type: 'open_radio' },
    };
  }

  /** Resolve a station name (favorites first, then the Radio Browser search) and play it. */
  private async playStationByName(name: string): Promise<{ reply: string; action?: VoiceUiAction }> {
    const needle = name.toLowerCase();
    const favs = (await this.radio.listFavorites()) ?? [];
    const exact = favs.find((s) => s.name.toLowerCase() === needle);
    const partial = favs.filter((s) => s.name.toLowerCase().includes(needle));
    const favMatch = exact ?? (partial.length === 1 ? partial[0] : undefined);

    if (favMatch) {
      this.playStation(favMatch);
      return { reply: `Sintonizando ${favMatch.name}.`, action: { type: 'open_radio' } };
    }
    if (partial.length > 1) {
      const names = partial.slice(0, 5).map((s) => s.name).join(', ');
      return {
        reply: `Tengo varias que coinciden: ${names}. ¿Cuál quieres?`,
        action: { type: 'choose_station', stations: partial },
      };
    }

    // Not in favorites — search the Radio Browser catalogue.
    let results: StationDto[] = [];
    try {
      results = await this.radio.search(name);
    } catch {
      return { reply: 'No puedo buscar emisoras ahora mismo; no hay conexión.' };
    }
    if (results.length === 0) {
      return { reply: `No he encontrado la emisora ${name}.` };
    }
    if (results.length === 1) {
      this.playStation(results[0]);
      return { reply: `Sintonizando ${results[0].name}.`, action: { type: 'open_radio' } };
    }
    const names = results.slice(0, 5).map((s) => s.name).join(', ');
    return {
      reply: `He encontrado varias: ${names}. ¿Cuál quieres?`,
      action: { type: 'choose_station', stations: results.slice(0, 5) },
    };
  }

  /** Tell the app to play a station (broadcast) and record it in history. */
  private playStation(station: StationDto): void {
    this.events.broadcast('voice_action', { type: 'radio_play', station });
    this.radio.recordHistory(station).catch(() => undefined);
  }

  // ---- weather (Open-Meteo) ----

  private async execWeatherCurrent(intent: VoiceIntent): Promise<string> {
    const city = intent.entities.city as string | undefined;
    const w = await this.weather.getCurrent(undefined, undefined, city);
    return (
      `En ${w.location.name} hace ${Math.round(w.temperature)} grados, ` +
      `${w.description.toLowerCase()}, sensación de ${Math.round(w.apparentTemperature)} ` +
      `y viento de ${Math.round(w.windSpeed)} kilómetros por hora.`
    );
  }

  private async execWeatherForecast(intent: VoiceIntent): Promise<string> {
    const city = intent.entities.city as string | undefined;
    const f = await this.weather.getForecast(undefined, undefined, city);
    const today = f.daily[0];
    if (!today) return 'No tengo la previsión ahora mismo.';
    return (
      `Para hoy en ${f.location.name}: máxima de ${Math.round(today.tempMax)} ` +
      `y mínima de ${Math.round(today.tempMin)} grados, con un ` +
      `${today.precipitationProbability}% de probabilidad de lluvia.`
    );
  }

  // ---- system status ----

  private execSystemStatus(): string {
    const r = this.system.getResources();
    const temp = this.system.getTemperature();
    const parts = [
      `Memoria usada al ${Math.round(r.memoryUsagePercent)} por ciento`,
      `carga del procesador ${r.loadAverage['1m'].toFixed(1)}`,
    ];
    if (temp.celsius != null) parts.push(`temperatura de ${Math.round(temp.celsius)} grados`);
    return `El sistema va bien: ${parts.join(', ')}.`;
  }

  private setStatus(status: VoiceState['status']): void {
    this.status = status;
    this.events.broadcast('voice_status', { status });
  }
}
