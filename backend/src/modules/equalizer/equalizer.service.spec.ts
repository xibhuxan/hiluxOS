import { EqualizerService } from './equalizer.service';
import { MockEqualizerDriver } from './drivers/mock-equalizer.driver';
import { BUILTIN_PRESETS, EQ_FREQS } from './drivers/equalizer.driver';
import { PrismaService } from '../../prisma/prisma.service';

/** In-memory stand-in for PrismaService covering the `setting` table. */
function fakePrisma(initial: Record<string, string> = {}) {
  const store = new Map<string, string>(Object.entries(initial));
  const setting = {
    findUnique: jest.fn((args: { where: { key: string } }) => {
      const key = args.where.key;
      return Promise.resolve(store.has(key) ? { key, value: store.get(key)! } : null);
    }),
    upsert: jest.fn((args: { where: { key: string }; create: { value: string } }) => {
      store.set(args.where.key, args.create.value);
      return Promise.resolve({ key: args.where.key, value: args.create.value });
    }),
  };
  return { prisma: { setting } as unknown as PrismaService, store };
}

describe('EqualizerService', () => {
  const make = (initial: Record<string, string> = {}) => {
    const driver = new MockEqualizerDriver();
    const { prisma, store } = fakePrisma(initial);
    return { svc: new EqualizerService(driver, prisma), driver, store };
  };

  describe('state', () => {
    it('starts flat with the fixed 8-band layout', () => {
      const { svc } = make();
      const state = svc.getState();
      expect(state.enabled).toBe(true);
      expect(state.bands).toHaveLength(8);
      expect(state.bands.map((b) => b.freq)).toEqual([...EQ_FREQS]);
      expect(state.bands.every((b) => b.gain === 0)).toBe(true);
      expect(state.balance).toBe(0);
    });

    it('exposes capabilities with the gain limits and frequencies', () => {
      const { svc } = make();
      const cap = svc.getCapabilities();
      expect(cap.available).toBe(true);
      expect(cap.bandCount).toBe(8);
      expect(cap.minGain).toBe(-12);
      expect(cap.maxGain).toBe(12);
    });
  });

  describe('update', () => {
    it('sets a full curve and clamps out-of-range gains', async () => {
      const { svc } = make();
      const state = await svc.update({ gains: [20, -20, 3.5, 0, 0, 0, 0, 0] });
      expect(state.bands[0].gain).toBe(12); // clamped to max
      expect(state.bands[1].gain).toBe(-12); // clamped to min
      expect(state.bands[2].gain).toBe(3.5);
    });

    it('updates balance and loudness and persists', async () => {
      const { svc, store } = make();
      const state = await svc.update({ balance: 0.5, loudness: true });
      expect(state.balance).toBe(0.5);
      expect(state.loudness).toBe(true);
      expect(store.has('equalizer.state')).toBe(true);
    });

    it('clamps balance into [-1, 1]', async () => {
      const { svc } = make();
      expect((await svc.update({ balance: 5 })).balance).toBe(1);
      expect((await svc.update({ balance: -5 })).balance).toBe(-1);
    });
  });

  describe('setBand', () => {
    it('changes one band and marks the curve custom (no preset)', async () => {
      const { svc } = make();
      const state = await svc.setBand(3, 6);
      expect(state.bands[3].gain).toBe(6);
      expect(state.activePreset).toBeNull();
    });
  });

  describe('reset', () => {
    it('returns to a flat curve', async () => {
      const { svc } = make();
      await svc.update({ gains: [8, 8, 8, 8, 8, 8, 8, 8] });
      const state = await svc.reset();
      expect(state.bands.every((b) => b.gain === 0)).toBe(true);
      expect(state.activePreset).toBe('Plano');
    });
  });

  describe('presets', () => {
    it('lists the built-in presets', () => {
      const { svc } = make();
      const names = svc.getPresets().map((p) => p.name);
      for (const b of BUILTIN_PRESETS) expect(names).toContain(b.name);
    });

    it('applies a preset curve and sets it active', async () => {
      const { svc } = make();
      const rock = BUILTIN_PRESETS.find((p) => p.name === 'Rock')!;
      const state = await svc.applyPreset('Rock');
      expect(state).not.toBeNull();
      expect(state!.bands.map((b) => b.gain)).toEqual(rock.gains);
      expect(state!.activePreset).toBe('Rock');
    });

    it('returns null for an unknown preset', async () => {
      const { svc } = make();
      expect(await svc.applyPreset('NoExiste')).toBeNull();
    });

    it('saves a custom preset that can be applied and deleted', async () => {
      const { svc } = make();
      await svc.savePreset('MiCurva', { gains: [1, 2, 3, 4, 5, 6, 7, 8] });
      expect(svc.getPresets().some((p) => p.name === 'MiCurva')).toBe(true);

      const applied = await svc.applyPreset('MiCurva');
      expect(applied!.bands.map((b) => b.gain)).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);

      expect(await svc.deletePreset('MiCurva')).toBe(true);
      expect(svc.getPresets().some((p) => p.name === 'MiCurva')).toBe(false);
    });

    it('refuses to delete a built-in preset', async () => {
      const { svc } = make();
      expect(await svc.deletePreset('Rock')).toBe(false);
    });
  });

  describe('persistence / restore', () => {
    it('restores the saved state on module init', async () => {
      const saved = {
        enabled: false,
        bands: EQ_FREQS.map((freq) => ({ freq, gain: 4 })),
        balance: -0.3,
        loudness: true,
        activePreset: 'Bass Boost',
      };
      const { svc } = make({ 'equalizer.state': JSON.stringify(saved) });
      await svc.onModuleInit();
      const state = svc.getState();
      expect(state.enabled).toBe(false);
      expect(state.bands[0].gain).toBe(4);
      expect(state.balance).toBe(-0.3);
      expect(state.loudness).toBe(true);
    });

    it('survives a broken DB (restore is best-effort)', async () => {
      const driver = new MockEqualizerDriver();
      const prisma = {
        setting: {
          findUnique: jest.fn(async () => {
            throw new Error('db down');
          }),
        },
      } as unknown as PrismaService;
      const svc = new EqualizerService(driver, prisma);
      await expect(svc.onModuleInit()).resolves.not.toThrow();
      expect(svc.getState().enabled).toBe(true); // defaults still work
    });
  });
});
