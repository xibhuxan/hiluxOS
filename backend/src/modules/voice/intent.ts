/**
 * Voice intent engine — parse a (already-transcribed) Spanish utterance into a
 * structured intent the orchestrator can execute.
 *
 * Pure and deterministic: no I/O, no randomness, no clock. This is the brain of
 * the voice assistant and is deliberately a standalone, heavily-unit-tested
 * module so the NLU quality can be iterated on independently of the ASR/TTS
 * plumbing (which needs a microphone and is validated on the Pi).
 */

/** The high-level thing the user wants to do. */
export type IntentKind =
  | 'navigate'
  | 'weather'
  | 'weather_forecast'
  | 'media_control'
  | 'radio'
  | 'call'
  | 'climate'
  | 'volume'
  | 'system_status'
  | 'help'
  | 'unknown';

/** A parsed intent: kind + extracted entities + confidence + a spoken reply. */
export interface VoiceIntent {
  kind: IntentKind;
  /** Confidence in [0, 1]; below ~0.5 the caller asks for clarification. */
  confidence: number;
  /** Extracted entities (destination, city, station, contact, action, …). */
  entities: Record<string, string | number>;
  /** The original (normalised) utterance. */
  raw: string;
  /** A short spoken confirmation / answer (Spanish), used for TTS. */
  reply: string;
}

/** Media transport actions the assistant can trigger. */
export type MediaAction = 'play' | 'pause' | 'next' | 'previous' | 'stop';

/** Normalise an utterance: lowercase, strip accents/punctuation, collapse spaces. */
export function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // strip diacritics (á→a, ñ→n)
    .replace(/[¿?¡!.,;:()"']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Spanish number words → digits, for "sube el volumen al veinte". */
const NUMBER_WORDS: Record<string, number> = {
  cero: 0, uno: 1, una: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5,
  seis: 6, siete: 7, ocho: 8, nueve: 9, diez: 10, once: 11, doce: 12,
  trece: 13, catorce: 14, quince: 15, dieciseis: 16, diecisiete: 17,
  dieciocho: 18, diecinueve: 19, veinte: 20, veinticinco: 25, treinta: 30,
  cuarenta: 40, cincuenta: 50, sesenta: 60, setenta: 70, ochenta: 80,
  noventa: 90, cien: 100,
};

/** Parse a number that may be digits or a Spanish word; null when absent. */
function parseNumber(raw: string): number | null {
  const n = raw.trim();
  if (/^\d+$/.test(n)) return parseInt(n, 10);
  return NUMBER_WORDS[n] ?? null;
}

/** Extract the place/argument after a verb, dropping a leading preposition. */
function extractPlace(norm: string, verbs: RegExp): string | null {
  const m = verbs.exec(norm);
  if (!m) return null;
  let rest = norm.slice(m.index + m[0].length).trim();
  // Drop a leading preposition, then an optional article ("a la calle" → "calle").
  rest = rest.replace(/^(a|al|hacia|hasta|para|de|en)\s+/, '');
  rest = rest.replace(/^(el|la|los|las)\s+/, '');
  return rest.length > 0 ? rest : null;
}

const NAV_VERBS = /(?:llevame|lleva|navega|dirigeme|vamos|como llego|como se llega|ruta a|ir a|ve a|quiero ir)/;
const WEATHER_WORDS = /(?:tiempo|clima|temperatura|llueve|llovera|va a llover|grados|hace calor|hace frio|pronostico|prevision)/;
const FORECAST_WORDS = /(?:manana|semana|proximos dias|pronostico|prevision|predecir)/;
const RADIO_WORDS = /(?:radio|emisora|sintoniza|\bfm\b)/;
const CALL_WORDS = /(?:llama|llamar|marca|telefono|haz una llamada)/;
const CLIMATE_WORDS = /(?:calefaccion|aire acondicionado|climatizador|\bac\b|ventilacion|desempen)/;
const VOLUME_WORDS = /(?:volumen|sube|baja|silencia|mute|mas alto|mas bajo)/;
const STATUS_WORDS = /(?:estado|bateria|sistema|consumo|cpu|memoria|como va el coche|nivel)/;
const HELP_WORDS = /(?:ayuda|que puedes hacer|que sabes hacer|comandos|opciones|auxilio)/;

const PLAY_WORDS = /(?:reproduce|ponme|toca|dale al play|reanuda|continua|\bplay\b|pon musica)/;
const PAUSE_WORDS = /(?:pausa|deten|para la musica|silencia la musica)/;
const NEXT_WORDS = /(?:siguiente|adelante|salta|otra cancion|proxima cancion)/;
const PREV_WORDS = /(?:anterior|vuelve atras|cancion anterior)/;


/**
 * Parse an utterance into a VoiceIntent. Returns `kind:'unknown'` (low
 * confidence) when nothing matches, so the caller can ask for clarification.
 */
export function parseIntent(text: string): VoiceIntent {
  const raw = normalize(text);
  const base = { raw };

  if (!raw) {
    return { kind: 'unknown', confidence: 0, entities: {}, ...base, reply: 'No te he oído. ¿Puedes repetirlo?' };
  }

  if (HELP_WORDS.test(raw)) {
    return {
      kind: 'help', confidence: 0.95, entities: {}, ...base,
      reply: 'Puedo navegar a un destino, decirte el tiempo, controlar la música y la radio, llamar a un contacto, ajustar el volumen o la climatización, y contarte el estado del coche. ¿Qué necesitas?',
    };
  }

  if (NAV_VERBS.test(raw) || /\b(destino|direccion|calle)\b/.test(raw)) {
    const dest = extractPlace(raw, NAV_VERBS) ?? extractPlace(raw, /\b(?:destino|direccion)\b/);
    if (dest) {
      return { kind: 'navigate', confidence: 0.9, entities: { destination: dest }, ...base, reply: `De acuerdo, calculando la ruta a ${dest}.` };
    }
    return { kind: 'navigate', confidence: 0.4, entities: {}, ...base, reply: '¿A dónde quieres ir?' };
  }

  if (WEATHER_WORDS.test(raw)) {
    const city = extractPlace(raw, /\ben\b/);
    if (FORECAST_WORDS.test(raw)) {
      return { kind: 'weather_forecast', confidence: 0.88, entities: city ? { city } : {}, ...base, reply: city ? `Te cuento la previsión para ${city}.` : 'Te cuento la previsión de los próximos días.' };
    }
    return { kind: 'weather', confidence: 0.88, entities: city ? { city } : {}, ...base, reply: city ? `Consultando el tiempo en ${city}.` : 'Consultando el tiempo actual.' };
  }

  // "pon X" where X is a bare station name → a radio station. This must run
  // before PLAY_WORDS so "pon Los 40" isn't read as media play. But it must NOT
  // hijack volume ("pon el volumen al veinte"), climate ("pon la calefacción")
  // or music ("pon música"), so those words are excluded first.
  if (!VOLUME_WORDS.test(raw) && !CLIMATE_WORDS.test(raw)) {
    const m = /^pon(?:me)?\s+(?:la\s+|el\s+)?(.+)$/.exec(raw);
    if (m && !/musica|cancion|radio|fm|emisora/.test(m[1])) {
      const station = m[1].trim();
      return { kind: 'radio', confidence: 0.85, entities: { station }, ...base, reply: `Sintonizando ${station}.` };
    }
  }

  if (RADIO_WORDS.test(raw)) {
    // The reply is a placeholder — the service resolves the real station and
    // overwrites it with the outcome (playing X / not found / disambiguation).
    const isStop = /(?:apaga|quita|deten|para|calla|stop)/.test(raw);
    if (isStop) {
      return { kind: 'radio', confidence: 0.85, entities: { action: 'stop' }, ...base, reply: 'Apagando la radio.' };
    }
    const isList = /(?:cuales|que emisoras|lista|listado|tengo|guardadas|favoritas)/.test(raw);
    if (isList) {
      return { kind: 'radio', confidence: 0.85, entities: { action: 'list' }, ...base, reply: 'Estas son tus emisoras favoritas.' };
    }
    // Specific station? Capture the argument after the verb, but not the bare
    // word "radio" itself ("pon la radio" = open radio, no specific station).
    let station = extractPlace(raw, /(?:sintoniza|escucha|ponme|pon|quiero oir|quiero escuchar)/);
    if (station && /^(radio|la radio|fm|emisoras?)$/.test(station)) station = null;
    return { kind: 'radio', confidence: 0.85, entities: station ? { station } : {}, ...base, reply: station ? `Sintonizando ${station}.` : 'Encendiendo la radio.' };
  }

  if (CALL_WORDS.test(raw)) {
    const contact = extractPlace(raw, /(?:llama|llamar|marca)/);
    if (contact) {
      return { kind: 'call', confidence: 0.85, entities: { contact }, ...base, reply: `Llamando a ${contact}.` };
    }
    return { kind: 'call', confidence: 0.4, entities: {}, ...base, reply: '¿A quién quieres llamar?' };
  }

  if (CLIMATE_WORDS.test(raw)) {
    const num = /\b(\d{1,2}|diecisiete|dieciocho|diecinueve|veinte|veinticinco)\b/.exec(raw);
    const deg = num ? parseNumber(num[1]) : null;
    const turning = /(?:enciende|activa|pon)\b/.test(raw) ? 'on' : /(?:apaga|desactiva|quita)\b/.test(raw) ? 'off' : null;
    return {
      kind: 'climate', confidence: 0.75,
      entities: { ...(deg != null ? { degrees: deg } : {}), ...(turning ? { action: turning } : {}) }, ...base,
      reply: deg != null ? `Ajustando la climatización a ${deg} grados.` : 'Ajustando la climatización.',
    };
  }

  if (VOLUME_WORDS.test(raw)) {
    if (/silencia|mute|calla/.test(raw)) {
      return { kind: 'volume', confidence: 0.9, entities: { action: 'mute' }, ...base, reply: 'Silenciando.' };
    }
    const num = /\b(\d{1,3}|cien|cincuenta|cuarenta|treinta|veinticinco|veinte|diez)\b/.exec(raw);
    const level = num ? parseNumber(num[1]) : null;
    if (/sube|mas alto|subir/.test(raw)) {
      return { kind: 'volume', confidence: 0.85, entities: { action: 'up', ...(level != null ? { level } : {}) }, ...base, reply: 'Subiendo el volumen.' };
    }
    if (/baja|mas bajo|bajar/.test(raw)) {
      return { kind: 'volume', confidence: 0.85, entities: { action: 'down', ...(level != null ? { level } : {}) }, ...base, reply: 'Bajando el volumen.' };
    }
    if (level != null) {
      return { kind: 'volume', confidence: 0.8, entities: { action: 'set', level }, ...base, reply: `Volumen al ${level} por ciento.` };
    }
    return { kind: 'volume', confidence: 0.4, entities: {}, ...base, reply: '¿Qué hago con el volumen?' };
  }

  if (NEXT_WORDS.test(raw)) {
    return { kind: 'media_control', confidence: 0.9, entities: { action: 'next' }, ...base, reply: 'Siguiente canción.' };
  }
  if (PREV_WORDS.test(raw)) {
    return { kind: 'media_control', confidence: 0.9, entities: { action: 'previous' }, ...base, reply: 'Canción anterior.' };
  }
  if (PAUSE_WORDS.test(raw)) {
    return { kind: 'media_control', confidence: 0.85, entities: { action: 'pause' }, ...base, reply: 'Pausando la música.' };
  }
  if (PLAY_WORDS.test(raw)) {
    return { kind: 'media_control', confidence: 0.85, entities: { action: 'play' }, ...base, reply: 'Reproduciendo.' };
  }

  if (STATUS_WORDS.test(raw)) {
    return { kind: 'system_status', confidence: 0.75, entities: {}, ...base, reply: 'Consultando el estado del sistema.' };
  }

  return {
    kind: 'unknown', confidence: 0.1, entities: {}, ...base,
    reply: 'Lo siento, no te he entendido. Di "ayuda" para ver lo que puedo hacer.',
  };
}
