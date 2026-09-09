import { VoiceService } from './voice.service';
import { MockVoiceDriver } from './drivers/mock-voice.driver';
import { OllamaService } from './ollama.service';
import { AssistantToolsService } from './assistant-tools.service';
import { EventsGateway } from '../events/events.gateway';
import { RadioService } from '../radio/radio.service';
import { SystemService } from '../system/system.service';
import { BtMediaService } from '../btmedia/btmedia.service';
import { WeatherService } from '../weather/weather.service';

/** A favourite-station-shaped object for the radio mock. */
const FAV = {
  id: 'fav-1',
  name: 'Los 40',
  url: 'http://los40.stream',
  favicon: null,
  country: 'Spain',
  codec: 'MP3',
  bitrate: 128,
  tags: [],
};

/**
 * Build a service over a mock driver with stubbed-out dependencies. The domain
 * services are jest mocks so each spec can programme exactly the path it needs
 * (a favourite that matches, a connected BT device, a weather reading, …).
 */
function makeService() {
  const driver = new MockVoiceDriver();
  const events = { broadcast: jest.fn() } as unknown as EventsGateway;
  const radio = {
    listFavorites: jest.fn().mockResolvedValue([FAV]),
    listHistory: jest.fn().mockResolvedValue([]),
    search: jest.fn().mockResolvedValue([]),
    recordHistory: jest.fn().mockResolvedValue(undefined),
  } as unknown as RadioService;
  const system = {
    getAudio: jest.fn().mockReturnValue({ volume: 50, muted: false }),
    setAudioVolume: jest.fn(),
    setAudioMuted: jest.fn(),
    getResources: jest.fn().mockReturnValue({
      memoryUsagePercent: 42,
      loadAverage: { '1m': 0.5, '5m': 0.4, '15m': 0.3 },
    }),
    getTemperature: jest.fn().mockReturnValue({ celsius: 47 }),
  } as unknown as SystemService;
  const btmedia = {
    getState: jest.fn().mockReturnValue({ connected: true }),
    play: jest.fn(),
    pause: jest.fn(),
    next: jest.fn(),
    previous: jest.fn(),
  } as unknown as BtMediaService;
  const weather = {
    getCurrent: jest.fn().mockResolvedValue({
      location: { name: 'Madrid' },
      temperature: 22.4,
      apparentTemperature: 21.8,
      description: 'Despejado',
      windSpeed: 12.3,
    }),
    getForecast: jest.fn().mockResolvedValue({
      location: { name: 'Madrid' },
      daily: [{ tempMax: 25, tempMin: 14, precipitationProbability: 10 }],
    }),
  } as unknown as WeatherService;
  // Ollama unavailable by default: the regex brain handles everything, so the
  // existing tests keep their deterministic behaviour. Specs that exercise the
  // LLM fallback override `isAvailable`/`chat` per-test.
  const ollama = {
    isAvailable: jest.fn().mockResolvedValue(false),
    chat: jest.fn(),
    model: 'test-model',
  } as unknown as OllamaService;
  const tools = {
    tools: [],
    run: jest.fn().mockResolvedValue({ text: 'ok' }),
  } as unknown as AssistantToolsService;
  const svc = new VoiceService(driver, events, radio, system, btmedia, weather, ollama, tools);
  return { svc, driver, events, radio, system, btmedia, weather, ollama, tools };
}

describe('VoiceService (mock driver)', () => {
  describe('state', () => {
    it('starts idle with ASR+TTS available (mock) and empty history', async () => {
      const { svc } = makeService();
      const s = await svc.getState();
      expect(s.status).toBe('idle');
      expect(s.availability.asr).toBe(true);
      expect(s.availability.tts).toBe(true);
      expect(s.history).toEqual([]);
    });
  });

  describe('text commands', () => {
    it('runs the intent pipeline and records the turn', async () => {
      const { svc } = makeService();
      const turn = await svc.handleTextCommand('llévame a Bilbao');
      expect(turn.intent).toBe('navigate');
      expect(turn.utterance).toBe('llévame a Bilbao');
      expect(turn.acted).toBe(true);
      expect(turn.reply).toMatch(/bilbao/i);
      expect(svc.getHistory()).toHaveLength(1);
    });

    it('marks low-confidence intents as not acted', async () => {
      const { svc } = makeService();
      const turn = await svc.handleTextCommand('quiero ir'); // no destination
      expect(turn.intent).toBe('navigate');
      expect(turn.acted).toBe(false);
    });

    it('handles unknown commands gracefully', async () => {
      const { svc } = makeService();
      const turn = await svc.handleTextCommand('asdf qwerty');
      expect(turn.intent).toBe('unknown');
      expect(turn.acted).toBe(false);
      expect(turn.reply).toMatch(/no te he entendido/i);
    });

    it('resolves a named station via the LLM (reads favourites) and plays it', async () => {
      const { svc, events, radio, ollama, tools } = makeService();
      // The parser no longer extracts the name — it hands the utterance to the
      // LLM. Simulate Ollama being up and the model choosing radio_play("Los 40"),
      // which the REAL AssistantToolsService maps to the catalogue.
      (ollama.isAvailable as jest.Mock).mockResolvedValue(true);
      (tools.run as jest.Mock).mockImplementation(async (name: string) =>
        name === 'radio_play'
          ? { text: 'Sintonizando Los 40.', action: { type: 'open_radio' } }
          : { text: 'ok' },
      );
      (ollama.chat as jest.Mock)
        .mockResolvedValueOnce({
          role: 'assistant', content: '',
          tool_calls: [{ function: { name: 'radio_play', arguments: { station: 'Los 40' } } }],
        })
        .mockResolvedValueOnce({ role: 'assistant', content: 'Sintonizando Los 40.' });

      const turn = await svc.handleTextCommand('pon Los 40');
      expect(turn.intent).toBe('radio_play');
      expect(turn.acted).toBe(true);
      expect(tools.run).toHaveBeenCalledWith('radio_play', { station: 'Los 40' });
      expect(turn.action?.type).toBe('open_radio');
      // listFavorites is read to give the model context for name resolution.
      expect(radio.listFavorites).toHaveBeenCalled();
      void events;
    });

    it('lists favourite stations when asked', async () => {
      const { svc } = makeService();
      const turn = await svc.handleTextCommand('qué emisoras tengo');
      expect(turn.intent).toBe('radio');
      expect(turn.reply).toMatch(/los 40/i);
      expect(turn.action?.type).toBe('choose_station');
      expect(turn.action?.stations).toHaveLength(1);
    });

    it('resumes the first favourite on a bare "pon la radio"', async () => {
      const { svc, events } = makeService();
      const turn = await svc.handleTextCommand('pon la radio');
      expect(turn.intent).toBe('radio');
      expect(turn.reply).toMatch(/encendiendo la radio/i);
      expect(events.broadcast).toHaveBeenCalledWith(
        'voice_action',
        expect.objectContaining({ type: 'radio_play' }),
      );
    });

    it('says when there are no favourites to list', async () => {
      const { svc, radio } = makeService();
      (radio.listFavorites as jest.Mock).mockResolvedValue([]);
      const turn = await svc.handleTextCommand('qué emisoras tengo');
      expect(turn.reply).toMatch(/no tienes emisoras favoritas/i);
    });

    it('sets an absolute volume level', async () => {
      const { svc, system } = makeService();
      const turn = await svc.handleTextCommand('volumen al 30');
      expect(turn.intent).toBe('volume');
      expect(system.setAudioVolume).toHaveBeenCalledWith(30);
      expect(turn.reply).toMatch(/30 por ciento/i);
    });

    it('steps the volume up from the current level', async () => {
      const { svc, system } = makeService();
      const turn = await svc.handleTextCommand('sube el volumen');
      expect(system.setAudioVolume).toHaveBeenCalledWith(60);
      expect(turn.reply).toMatch(/60 por ciento/i);
    });

    it('mutes on "silencia"', async () => {
      const { svc, system } = makeService();
      await svc.handleTextCommand('silencia el volumen');
      expect(system.setAudioMuted).toHaveBeenCalledWith(true);
    });

    it('answers the weather with real data', async () => {
      const { svc, weather } = makeService();
      const turn = await svc.handleTextCommand('qué tiempo hace');
      expect(turn.intent).toBe('weather');
      expect(weather.getCurrent).toHaveBeenCalled();
      expect(turn.reply).toMatch(/grados/i);
    });

    it('controls Bluetooth media when a device is connected', async () => {
      const { svc, btmedia } = makeService();
      const turn = await svc.handleTextCommand('siguiente canción');
      expect(turn.intent).toBe('media_control');
      expect(btmedia.next).toHaveBeenCalled();
      expect(turn.reply).toMatch(/siguiente/i);
    });

    it('reports when no Bluetooth device is connected', async () => {
      const { svc, btmedia } = makeService();
      (btmedia.getState as jest.Mock).mockReturnValue({ connected: false });
      const turn = await svc.handleTextCommand('pon música');
      expect(turn.reply).toMatch(/bluetooth/i);
    });

    it('broadcasts a voice event for each turn', async () => {
      const { svc, events } = makeService();
      await svc.handleTextCommand('qué tiempo hace');
      expect(events.broadcast).toHaveBeenCalledWith(
        'voice',
        expect.objectContaining({ intent: 'weather' }),
      );
    });
  });

  describe('audio commands', () => {
    it('transcribes via the driver then runs the pipeline', async () => {
      const { svc, driver } = makeService();
      driver.script = ['qué tiempo hace'];
      const turn = await svc.handleAudioCommand(Buffer.from([0, 1, 2]));
      expect(turn.intent).toBe('weather');
      expect(turn.utterance).toBe('qué tiempo hace');
    });

    it('labels inaudible audio', async () => {
      const { svc, driver } = makeService();
      driver.script = ['']; // driver recognised nothing
      const turn = await svc.handleAudioCommand(Buffer.from([0]));
      expect(turn.utterance).toBe('(inaudible)');
      expect(turn.intent).toBe('unknown');
    });
  });

  describe('speak', () => {
    it('returns a valid WAV buffer', async () => {
      const { svc } = makeService();
      const wav = await svc.speak('Hola');
      expect(wav.subarray(0, 4).toString()).toBe('RIFF');
      expect(wav.subarray(8, 12).toString()).toBe('WAVE');
      expect(wav.length).toBeGreaterThan(44);
    });

    it('restores idle status after speaking', async () => {
      const { svc } = makeService();
      await svc.speak('Hola');
      const s = await svc.getState();
      expect(s.status).toBe('idle');
    });
  });

  describe('history', () => {
    it('caps the history at 50 turns', async () => {
      const { svc } = makeService();
      for (let i = 0; i < 60; i++) {
        await svc.handleTextCommand(`comando ${i}`);
      }
      expect(svc.getHistory().length).toBe(50);
    });

    it('clears the history', async () => {
      const { svc } = makeService();
      await svc.handleTextCommand('hola');
      svc.clearHistory();
      expect(svc.getHistory()).toEqual([]);
    });
  });

  describe('LLM fallback (Ollama)', () => {
    it('keeps the parser reply when Ollama is unavailable', async () => {
      const { svc, ollama } = makeService();
      (ollama.isAvailable as jest.Mock).mockResolvedValue(false);
      const turn = await svc.handleTextCommand('asdf qwerty');
      expect(turn.intent).toBe('unknown');
      expect(turn.acted).toBe(false);
      expect(turn.reply).toMatch(/no te he entendido|ayuda/i);
      expect(ollama.chat).not.toHaveBeenCalled();
    });

    it('answers a free-form question via the LLM when the parser fails', async () => {
      const { svc, ollama } = makeService();
      (ollama.isAvailable as jest.Mock).mockResolvedValue(true);
      (ollama.chat as jest.Mock).mockResolvedValue({
        role: 'assistant',
        content: 'La capital de Francia es París.',
      });
      const turn = await svc.handleTextCommand('cuál es la capital de Francia');
      expect(turn.intent).toBe('chat');
      expect(turn.acted).toBe(false);
      expect(turn.reply).toMatch(/París/);
    });

    it('executes a tool the model asks for and speaks the result', async () => {
      const { svc, ollama, tools } = makeService();
      (ollama.isAvailable as jest.Mock).mockResolvedValue(true);
      (tools.run as jest.Mock).mockResolvedValue({ text: 'Anotado: cambiar aceite.' });
      (ollama.chat as jest.Mock)
        // First round: the model requests the add_task tool.
        .mockResolvedValueOnce({
          role: 'assistant',
          content: '',
          tool_calls: [{ function: { name: 'add_task', arguments: { title: 'cambiar aceite' } } }],
        })
        // Second round: after the tool result, it produces the spoken reply.
        .mockResolvedValueOnce({ role: 'assistant', content: 'Anotado: cambiar aceite.' });
      const turn = await svc.handleTextCommand('recuérdame cambiar el aceite');
      expect(tools.run).toHaveBeenCalledWith('add_task', { title: 'cambiar aceite' });
      expect(turn.intent).toBe('add_task');
      expect(turn.acted).toBe(true);
      expect(turn.reply).toMatch(/aceite/i);
    });

    it('falls back to the parser reply when the LLM call throws', async () => {
      const { svc, ollama } = makeService();
      (ollama.isAvailable as jest.Mock).mockResolvedValue(true);
      (ollama.chat as jest.Mock).mockRejectedValue(new Error('connection refused'));
      const turn = await svc.handleTextCommand('asdf qwerty');
      expect(turn.intent).toBe('unknown');
      expect(turn.acted).toBe(false);
      expect(turn.reply).toMatch(/no te he entendido|ayuda/i);
    });

    it('propagates a UI action returned by a tool', async () => {
      const { svc, ollama, tools } = makeService();
      (ollama.isAvailable as jest.Mock).mockResolvedValue(true);
      (tools.run as jest.Mock).mockResolvedValue({
        text: 'Abriendo la radio.',
        action: { type: 'open_radio' },
      });
      (ollama.chat as jest.Mock)
        .mockResolvedValueOnce({
          role: 'assistant',
          content: '',
          tool_calls: [{ function: { name: 'open_screen', arguments: { screen: 'radio' } } }],
        })
        .mockResolvedValueOnce({ role: 'assistant', content: 'Abriendo la radio.' });
      const turn = await svc.handleTextCommand('ábreme la radio por favor');
      expect(turn.action).toEqual({ type: 'open_radio' });
    });
  });
});
