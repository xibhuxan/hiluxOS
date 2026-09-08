import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  BUILTIN_PRESETS,
  clampBalance,
  clampGain,
  EqPreset,
  EqState,
  EqualizerDriver,
  flatEqState,
} from './drivers/equalizer.driver';

/** DI token for the substituted driver (bound in equalizer.module.ts). */
export const EQ_DRIVER = Symbol('EQ_DRIVER');

const STATE_KEY = 'equalizer.state';
const CUSTOM_PRESETS_KEY = 'equalizer.customPresets';

/**
 * Facade over the active EqualizerDriver, adding persistence and presets.
 *
 * - Every mutating call forwards to the driver, then saves the resulting
 *   state to the `settings` table so the curve survives restarts.
 * - On boot the saved state is restored onto the driver.
 * - Presets combine the built-in list with user-saved ones (custom presets
 *   can shadow a built-in by name, and can be deleted).
 *
 * Contains no hardware logic — that's the driver's job (ARCHITECTURE.md).
 */
@Injectable()
export class EqualizerService implements OnModuleInit {
  private readonly logger = new Logger(EqualizerService.name);
  private customPresets: EqPreset[] = [];

  constructor(
    @Inject(EQ_DRIVER) private readonly driver: EqualizerDriver,
    private readonly prisma: PrismaService,
  ) {}

  /** Restore the persisted curve + custom presets onto the driver at boot. */
  async onModuleInit(): Promise<void> {
    try {
      const row = await this.prisma.setting.findUnique({ where: { key: STATE_KEY } });
      if (row) {
        const saved = JSON.parse(row.value) as Partial<EqState>;
        this.driver.applyState(this.toState(saved));
      }
      const presets = await this.prisma.setting.findUnique({
        where: { key: CUSTOM_PRESETS_KEY },
      });
      if (presets) this.customPresets = JSON.parse(presets.value) as EqPreset[];
    } catch (err) {
      // Persistence is best-effort: a fresh DB or offline mode must never
      // stop the EQ from working with defaults.
      this.logger.warn(`EQ state restore skipped: ${err}`);
    }
  }

  /** Current capabilities of the active driver. */
  getCapabilities() {
    return this.driver.getCapabilities();
  }

  /** The full equalizer state. */
  getState(): EqState {
    return this.driver.getState();
  }

  /** Apply a partial update; persists the resulting state. */
  async update(partial: {
    enabled?: boolean;
    gains?: number[];
    balance?: number;
    loudness?: boolean;
    activePreset?: string | null;
  }): Promise<EqState> {
    if (typeof partial.enabled === 'boolean') this.driver.setEnabled(partial.enabled);
    if (typeof partial.loudness === 'boolean') this.driver.setLoudness(partial.loudness);
    if (typeof partial.balance === 'number') this.driver.setBalance(partial.balance);
    if (partial.gains) {
      const current = this.driver.getState();
      const bands = current.bands.map((b, i) => ({
        ...b,
        gain: partial.gains![i] !== undefined ? clampGain(partial.gains![i]) : b.gain,
      }));
      this.driver.applyState({
        ...current,
        bands,
        activePreset:
          partial.activePreset !== undefined ? partial.activePreset : current.activePreset,
      });
    }
    const state = this.driver.getState();
    await this.persist(state);
    return state;
  }

  /** Set one band's gain. */
  async setBand(index: number, gain: number): Promise<EqState> {
    const state = this.driver.setBandGain(index, gain);
    await this.persist(state);
    return state;
  }

  /** Reset to a flat curve. */
  async reset(): Promise<EqState> {
    const state = this.driver.applyState(flatEqState());
    await this.persist(state);
    return state;
  }

  /** All presets: built-ins plus user-saved (custom shadows built-in by name). */
  getPresets(): EqPreset[] {
    const map = new Map<string, EqPreset>();
    for (const p of BUILTIN_PRESETS) map.set(p.name, p);
    for (const p of this.customPresets) map.set(p.name, p);
    return [...map.values()];
  }

  /** Apply a named preset. Returns null when the preset doesn't exist. */
  async applyPreset(name: string): Promise<EqState | null> {
    const preset = this.getPresets().find((p) => p.name === name);
    if (!preset) return null;
    const current = this.driver.getState();
    const state = this.driver.applyState({
      ...current,
      bands: current.bands.map((b, i) => ({ ...b, gain: preset.gains[i] ?? 0 })),
      balance: clampBalance(preset.balance),
      loudness: preset.loudness,
      activePreset: preset.name,
    });
    await this.persist(state);
    return state;
  }

  /** Save (create/overwrite) a user preset. */
  async savePreset(
    name: string,
    preset: { gains: number[]; balance?: number; loudness?: boolean },
  ): Promise<EqPreset[]> {
    const full: EqPreset = {
      name,
      gains: preset.gains.map((g) => clampGain(g)),
      balance: clampBalance(preset.balance ?? 0),
      loudness: preset.loudness ?? false,
    };
    this.customPresets = [...this.customPresets.filter((p) => p.name !== name), full];
    await this.persistPresets();
    return this.getPresets();
  }

  /** Delete a user preset. Built-ins cannot be deleted. Returns success. */
  async deletePreset(name: string): Promise<boolean> {
    if (BUILTIN_PRESETS.some((p) => p.name === name)) return false;
    const before = this.customPresets.length;
    this.customPresets = this.customPresets.filter((p) => p.name !== name);
    if (this.customPresets.length === before) return false;
    await this.persistPresets();
    return true;
  }

  // ---- persistence helpers ----

  private async persist(state: EqState): Promise<void> {
    try {
      const value = JSON.stringify(state);
      await this.prisma.setting.upsert({
        where: { key: STATE_KEY },
        update: { value },
        create: { key: STATE_KEY, value },
      });
    } catch (err) {
      this.logger.warn(`EQ state persist failed: ${err}`);
    }
  }

  private async persistPresets(): Promise<void> {
    try {
      const value = JSON.stringify(this.customPresets);
      await this.prisma.setting.upsert({
        where: { key: CUSTOM_PRESETS_KEY },
        update: { value },
        create: { key: CUSTOM_PRESETS_KEY, value },
      });
    } catch (err) {
      this.logger.warn(`EQ presets persist failed: ${err}`);
    }
  }

  /** Build a complete EqState from a partial persisted blob. */
  private toState(saved: Partial<EqState>): EqState {
    const base = flatEqState();
    return {
      enabled: saved.enabled ?? base.enabled,
      bands: base.bands.map((b, i) => ({ ...b, gain: saved.bands?.[i]?.gain ?? 0 })),
      balance: clampBalance(saved.balance ?? 0),
      loudness: saved.loudness ?? false,
      activePreset: saved.activePreset ?? null,
    };
  }
}
