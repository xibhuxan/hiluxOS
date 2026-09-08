import {
  clampBalance,
  clampGain,
  EqCapabilities,
  EQ_FREQS,
  EQ_MAX_GAIN,
  EQ_MIN_GAIN,
  EqualizerDriver,
  EqState,
  flatEqState,
} from './equalizer.driver';

/**
 * Simulated equalizer (default driver): keeps the state in memory and applies
 * the same validation/clamping a real driver would. Deterministic and free of
 * I/O — unit tests and development run against this without touching audio.
 */
export class MockEqualizerDriver extends EqualizerDriver {
  readonly kind = 'mock';
  private state: EqState = flatEqState();

  getCapabilities(): EqCapabilities {
    return {
      available: true,
      bandCount: EQ_FREQS.length,
      minGain: EQ_MIN_GAIN,
      maxGain: EQ_MAX_GAIN,
      freqs: [...EQ_FREQS],
    };
  }

  getState(): EqState {
    return this.copy();
  }

  applyState(state: EqState): EqState {
    this.state = this.normalize(state);
    return this.copy();
  }

  setBandGain(index: number, gain: number): EqState {
    if (index >= 0 && index < this.state.bands.length) {
      this.state.bands[index] = { ...this.state.bands[index], gain: clampGain(gain) };
      this.state.activePreset = null; // manual tweak → custom curve
    }
    return this.copy();
  }

  setBalance(balance: number): EqState {
    this.state.balance = clampBalance(balance);
    return this.copy();
  }

  setEnabled(enabled: boolean): EqState {
    this.state.enabled = enabled;
    return this.copy();
  }

  setLoudness(loudness: boolean): EqState {
    this.state.loudness = loudness;
    return this.copy();
  }

  /** Deep copy so callers can't mutate driver internals. */
  private copy(): EqState {
    return {
      ...this.state,
      bands: this.state.bands.map((b) => ({ ...b })),
    };
  }

  /** Clamp every field of an incoming state into the valid range. */
  private normalize(state: EqState): EqState {
    const bands = EQ_FREQS.map((freq, i) => ({
      freq,
      gain: clampGain(state.bands[i]?.gain ?? 0),
    }));
    return {
      enabled: state.enabled,
      bands,
      balance: clampBalance(state.balance),
      loudness: state.loudness,
      activePreset: state.activePreset,
    };
  }
}
