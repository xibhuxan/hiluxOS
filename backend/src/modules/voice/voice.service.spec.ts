import { VoiceService } from './voice.service';
import { MockVoiceDriver } from './drivers/mock-voice.driver';
import { EventsGateway } from '../events/events.gateway';

/** Build a service over a mock driver with a stubbed-out event bus. */
function makeService() {
  const driver = new MockVoiceDriver();
  const events = { broadcast: jest.fn() } as unknown as EventsGateway;
  const svc = new VoiceService(driver, events);
  return { svc, driver, events };
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
});
