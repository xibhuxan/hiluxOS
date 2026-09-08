/**
 * Equalizer HAL — driver interface.
 *
 * A parametric/graphic audio equalizer applied system-wide on the default
 * output. The UI talks only to this abstraction; the substituted driver does
 * the real work (PipeWire filter-chain) or simulates it (mock).
 *
 * Substitution chain (ARCHITECTURE.md): MockEqualizerDriver (default) →
 * PipeWireEqualizerDriver (creates a `filter-chain` node of `bq_peaking`
 * biquads via pw-cli). Selection by env: `EQ_DRIVER=mock|pipewire`.
 *
 * The equalizer is modelled as a fixed set of frequency bands, each with a
 * gain in dB, plus output balance and a loudness (bass-boost-at-low-volume)
 * toggle. This maps naturally onto PipeWire's `bq_peaking` filter nodes and a
 * per-channel gain for balance.
 */

/** One equalizer band. */
export interface EqBand {
  /** Centre frequency in Hz (fixed per band; UI shows it as the label). */
  freq: number;
  /** Gain in dB, typically clamped to [-12, +12]. */
  gain: number;
}

/** The full equalizer state. */
export interface EqState {
  /** Master on/off — when off the EQ chain is bypassed (flat passthrough). */
  enabled: boolean;
  /** Per-band gains, ordered low → high frequency. Length = capabilities.bands. */
  bands: EqBand[];
  /** Stereo balance in [-1, 1]: -1 = full left, 0 = centre, +1 = full right. */
  balance: number;
  /** Loudness compensation (boosts bass at low listening volume). */
  loudness: boolean;
  /** Name of the active preset, or null when the curve is custom/unsaved. */
  activePreset: string | null;
}

/** What the active driver can actually do right now. */
export interface EqCapabilities {
  /** Whether a real audio backend is available (false → UI shows "no audio"). */
  available: boolean;
  /** Number of bands the chain supports. */
  bandCount: number;
  /** Min/max gain per band in dB. */
  minGain: number;
  maxGain: number;
  /** The fixed centre frequencies (Hz) of each band, low → high. */
  freqs: number[];
}

/** A named, reusable EQ curve. */
export interface EqPreset {
  name: string;
  /** Per-band gains in dB (same length as capabilities.bands). */
  gains: number[];
  /** Balance stored with the preset (defaults to 0). */
  balance: number;
  /** Loudness stored with the preset (defaults to false). */
  loudness: boolean;
}

/**
 * The fixed 8-band layout used across hiluxOS — octave-spaced from 60 Hz to
 * 16 kHz. This is the classic car-audio graphic EQ spread: enough control to
 * shape the cabin response without overwhelming the driver UI.
 */
export const EQ_FREQS: readonly number[] = [60, 120, 250, 500, 1000, 2000, 4000, 8000];

/** Gain limits (dB) applied to every band. */
export const EQ_MIN_GAIN = -12;
export const EQ_MAX_GAIN = 12;

/** Built-in presets, always present alongside user-defined ones. */
export const BUILTIN_PRESETS: readonly EqPreset[] = [
  { name: 'Plano', gains: [0, 0, 0, 0, 0, 0, 0, 0], balance: 0, loudness: false },
  { name: 'Rock', gains: [4, 3, 1, -1, -2, 1, 3, 4], balance: 0, loudness: false },
  { name: 'Pop', gains: [-1, 1, 3, 4, 3, 1, -1, -1], balance: 0, loudness: false },
  { name: 'Bass Boost', gains: [6, 5, 3, 1, 0, 0, 0, 0], balance: 0, loudness: true },
  { name: 'Vocal', gains: [-2, -3, -1, 2, 5, 5, 3, 0], balance: 0, loudness: false },
  { name: 'Graves coche', gains: [5, 4, 2, 0, 1, 2, 3, 3], balance: 0, loudness: true },
];

/** Flat (unity) state — every band at 0 dB, centred balance, EQ enabled. */
export function flatEqState(): EqState {
  return {
    enabled: true,
    bands: EQ_FREQS.map((freq) => ({ freq, gain: 0 })),
    balance: 0,
    loudness: false,
    activePreset: 'Plano',
  };
}

/** Clamp a gain to the allowed range, rounded to 1 decimal. */
export function clampGain(gain: number): number {
  const g = Math.min(EQ_MAX_GAIN, Math.max(EQ_MIN_GAIN, gain));
  return Math.round(g * 10) / 10;
}

/** Clamp balance to [-1, 1], rounded to 2 decimals. */
export function clampBalance(balance: number): number {
  const b = Math.min(1, Math.max(-1, balance));
  return Math.round(b * 100) / 100;
}

/**
 * Abstract driver — the service/controller layers only ever see this.
 *
 * Implementations keep the *applied* state themselves (the mock in memory,
 * the PipeWire one reflected onto the live filter-chain) so `getState()` is
 * cheap and never re-parses the audio graph.
 */
export abstract class EqualizerDriver {
  abstract readonly kind: string;

  /** Current capabilities (available / band count / limits). */
  abstract getCapabilities(): EqCapabilities;

  /** The currently-applied equalizer state. */
  abstract getState(): EqState;

  /** Replace the whole state (used by apply-preset and restore-on-boot). */
  abstract applyState(state: EqState): EqState;

  /** Set one band's gain (index into bands). */
  abstract setBandGain(index: number, gain: number): EqState;

  /** Set the stereo balance. */
  abstract setBalance(balance: number): EqState;

  /** Toggle the whole EQ on/off. */
  abstract setEnabled(enabled: boolean): EqState;

  /** Toggle loudness compensation. */
  abstract setLoudness(loudness: boolean): EqState;
}
