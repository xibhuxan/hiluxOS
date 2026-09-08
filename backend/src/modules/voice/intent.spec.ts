import { normalize, parseIntent } from './intent';

describe('normalize', () => {
  it('lowercases, strips accents and punctuation, collapses spaces', () => {
    expect(normalize('  ¿Qué TIEMPO hace en  León? ')).toBe('que tiempo hace en leon');
  });

  it('strips ñ and ü correctly', () => {
    expect(normalize('España pingüino')).toBe('espana pinguino');
  });
});

describe('parseIntent', () => {
  describe('navigation', () => {
    it.each([
      ['llévame a Bilbao', 'bilbao'],
      ['navega a la calle mayor', 'calle mayor'],
      ['cómo llego al aeropuerto', 'aeropuerto'],
      ['quiero ir a casa', 'casa'],
      ['ruta a Valencia', 'valencia'],
    ])('parses "%s" → destination "%s"', (utterance, dest) => {
      const i = parseIntent(utterance);
      expect(i.kind).toBe('navigate');
      expect(i.entities.destination).toBe(dest);
      expect(i.confidence).toBeGreaterThan(0.5);
    });

    it('asks for the destination when none is given', () => {
      const i = parseIntent('quiero ir');
      expect(i.kind).toBe('navigate');
      expect(i.confidence).toBeLessThan(0.5);
      expect(i.reply).toMatch(/dónde/i);
    });
  });

  describe('weather', () => {
    it('parses a current-weather query without a city', () => {
      const i = parseIntent('¿qué tiempo hace?');
      expect(i.kind).toBe('weather');
      expect(i.entities.city).toBeUndefined();
    });

    it('parses a current-weather query with a city', () => {
      const i = parseIntent('¿qué tiempo hace en Sevilla?');
      expect(i.kind).toBe('weather');
      expect(i.entities.city).toBe('sevilla');
    });

    it('parses a forecast query', () => {
      const i = parseIntent('¿va a llover mañana?');
      expect(i.kind).toBe('weather_forecast');
    });

    it('parses a temperature question', () => {
      const i = parseIntent('¿cuántos grados hace?');
      expect(i.kind).toBe('weather');
    });
  });

  describe('media control', () => {
    it('parses next', () => {
      expect(parseIntent('siguiente canción').entities.action).toBe('next');
      expect(parseIntent('salta').entities.action).toBe('next');
    });
    it('parses previous', () => {
      expect(parseIntent('canción anterior').entities.action).toBe('previous');
    });
    it('parses pause', () => {
      expect(parseIntent('pausa la música').entities.action).toBe('pause');
    });
    it('parses play', () => {
      expect(parseIntent('pon música').entities.action).toBe('play');
      expect(parseIntent('reanuda').entities.action).toBe('play');
    });
  });

  describe('volume', () => {
    it('parses up/down', () => {
      expect(parseIntent('sube el volumen').entities.action).toBe('up');
      expect(parseIntent('baja el volumen').entities.action).toBe('down');
    });
    it('parses mute', () => {
      expect(parseIntent('silencia').entities.action).toBe('mute');
    });
    it('parses an absolute level in digits', () => {
      const i = parseIntent('volumen al 50');
      expect(i.entities.action).toBe('set');
      expect(i.entities.level).toBe(50);
    });
    it('parses an absolute level in words', () => {
      const i = parseIntent('pon el volumen al veinte');
      expect(i.entities.action).toBe('set');
      expect(i.entities.level).toBe(20);
    });
  });

  describe('radio', () => {
    it('parses turning on the radio', () => {
      expect(parseIntent('pon la radio').kind).toBe('radio');
    });
    it('extracts a station when present', () => {
      const i = parseIntent('sintoniza la cope');
      expect(i.kind).toBe('radio');
      expect(i.entities.station).toBe('cope');
    });
  });

  describe('call', () => {
    it('extracts a contact', () => {
      const i = parseIntent('llama a mamá');
      expect(i.kind).toBe('call');
      expect(i.entities.contact).toBe('mama');
    });
    it('asks for the contact when none is given', () => {
      const i = parseIntent('llama');
      expect(i.kind).toBe('call');
      expect(i.confidence).toBeLessThan(0.5);
    });
  });

  describe('climate', () => {
    it('parses a target temperature', () => {
      const i = parseIntent('pon la calefacción a 21');
      expect(i.kind).toBe('climate');
      expect(i.entities.degrees).toBe(21);
    });
    it('parses turning the AC on', () => {
      const i = parseIntent('enciende el aire acondicionado');
      expect(i.kind).toBe('climate');
      expect(i.entities.action).toBe('on');
    });
  });

  describe('misc', () => {
    it('parses system status', () => {
      expect(parseIntent('¿cómo va el coche?').kind).toBe('system_status');
    });
    it('parses help', () => {
      const i = parseIntent('¿qué puedes hacer?');
      expect(i.kind).toBe('help');
      expect(i.reply.length).toBeGreaterThan(20);
    });
    it('returns unknown for gibberish', () => {
      const i = parseIntent('asdf qwerty zzz');
      expect(i.kind).toBe('unknown');
      expect(i.confidence).toBeLessThan(0.5);
    });
    it('returns unknown for empty input', () => {
      expect(parseIntent('   ').kind).toBe('unknown');
    });
  });
});
