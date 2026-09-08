import { CommandRunner } from '../../system/command-runner';
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
 * Real equalizer on PipeWire, via a `filter-chain` node of `bq_peaking`
 * biquads — the same mechanism EasyEffects uses under the hood.
 *
 * Strategy:
 *  - A single filter-chain node named `hiluxos_eq` is (re)created whenever the
 *    curve changes. Each band becomes a `bq_peaking` filter; balance becomes a
 *    per-channel gain node; loudness a low-shelf engaged on demand.
 *  - The node is made the default sink so every app routes through it.
 *  - If PipeWire/pw-cli isn't reachable the driver reports
 *    `available:false` and every setter is a no-op, mirroring how
 *    RpiPowerDriver degrades when vcgencmd is missing. The applied state is
 *    still tracked so the UI stays consistent and can re-apply on reconnect.
 */
export class PipeWireEqualizerDriver extends EqualizerDriver {
  readonly kind = 'pipewire';
  private state: EqState = flatEqState();
  /** PipeWire object id of the live filter-chain node, once created. */
  private nodeId: number | null = null;

  constructor(private readonly cmd: CommandRunner) {
    super();
  }

  getCapabilities(): EqCapabilities {
    return {
      available: this.pipewireAvailable(),
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
    this.rebuild();
    return this.copy();
  }

  setBandGain(index: number, gain: number): EqState {
    if (index >= 0 && index < this.state.bands.length) {
      this.state.bands[index] = { ...this.state.bands[index], gain: clampGain(gain) };
      this.state.activePreset = null;
      this.rebuild();
    }
    return this.copy();
  }

  setBalance(balance: number): EqState {
    this.state.balance = clampBalance(balance);
    this.rebuild();
    return this.copy();
  }

  setEnabled(enabled: boolean): EqState {
    this.state.enabled = enabled;
    this.rebuild();
    return this.copy();
  }

  setLoudness(loudness: boolean): EqState {
    this.state.loudness = loudness;
    this.rebuild();
    return this.copy();
  }

  // ---- PipeWire plumbing ----

  /** Is a PipeWire daemon reachable through pw-cli? */
  private pipewireAvailable(): boolean {
    return this.cmd.run('pw-cli', ['ls', 'Node']) !== null;
  }

  /**
   * (Re)build the filter-chain node to reflect the current state. When the EQ
   * is disabled or PipeWire is unavailable the node is torn down instead, so
   * audio flows unmodified.
   */
  private rebuild(): void {
    this.destroyNode();
    if (!this.state.enabled || !this.pipewireAvailable()) return;

    const spec = this.buildNodeSpec();
    const out = this.cmd.run('pw-cli', ['create-node', 'adapter', spec]);
    // pw-cli prints the created object id on success; keep it for later
    // teardown. If it printed nothing we look the node up by name.
    const id = this.parseCreatedId(out) ?? this.findNodeIdByName();
    this.nodeId = id;
    if (id !== null) this.setDefaultSink(id);
  }

  /** Build the `create-node adapter` property string for the filter-chain. */
  private buildNodeSpec(): string {
    const nodes: string[] = [];

    // One peaking biquad per band. PipeWire's builtin bq_peaking
    // (Freq/Q/Gain) shapes the curve; we give each band a moderate Q of 1.
    for (const band of this.state.bands) {
      nodes.push(
        `{ type=builtin label=bq_peaking control={ Freq=${band.freq}.0 Q=1.0 Gain=${band.gain.toFixed(1)} } }`,
      );
    }

    // Loudness: a low-shelf boost at 100 Hz to compensate for low volume.
    if (this.state.loudness) {
      nodes.push('{ type=builtin label=bq_lowshelf control={ Freq=100.0 Gain=4.0 } }');
    }

    // Balance: per-channel gain. balance -1 → mute right, +1 → mute left.
    const left = 1 - Math.max(0, this.state.balance);
    const right = 1 + Math.min(0, this.state.balance);
    if (this.state.balance !== 0) {
      nodes.push(
        `{ type=builtin label=channelmix control={ "Gain L"=${left.toFixed(2)} "Gain R"=${right.toFixed(2)} } }`,
      );
    }

    const graph = `filter.graph={ nodes=[ ${nodes.join(' ')} ] }`;
    return (
      `{ factory.name=support.filter-chain node.name="hiluxos_eq" ` +
      `node.description="hiluxOS EQ" media.class=Audio/Sink object.linger=true ` +
      `${graph} capture.props={ node.target="@DEFAULT_SINK@" } }`
    );
  }

  /** Destroy the existing filter-chain node, if we created one. */
  private destroyNode(): void {
    const id = this.nodeId ?? this.findNodeIdByName();
    if (id !== null) {
      this.cmd.run('pw-cli', ['destroy', String(id)]);
      this.nodeId = null;
    }
  }

  /** Look up our node's object id by name from `pw-cli ls Node`. */
  private findNodeIdByName(): number | null {
    const out = this.cmd.run('pw-cli', ['ls', 'Node']);
    if (!out) return null;
    // Blocks are separated by a header line `id NN, type ...`. Find the block
    // that mentions node.name = "hiluxos_eq" and grab its id.
    const blocks = out.split(/\n(?=\tid \d+)/);
    for (const block of blocks) {
      if (/node\.name\s*=\s*"hiluxos_eq"/.test(block)) {
        const m = /\bid\s+(\d+)/.exec(block);
        if (m) return parseInt(m[1], 10);
      }
    }
    return null;
  }

  /** Parse a numeric id out of `create-node` stdout (if it printed one). */
  private parseCreatedId(out: string | null): number | null {
    if (!out) return null;
    const m = /(\d+)/.exec(out);
    return m ? parseInt(m[1], 10) : null;
  }

  /** Route the default output through the EQ node. */
  private setDefaultSink(id: number): void {
    // wpctl set-default accepts a node id; failures are non-fatal (the node
    // still exists and can be selected manually in the mixer).
    this.cmd.run('wpctl', ['set-default', String(id)]);
  }

  private copy(): EqState {
    return { ...this.state, bands: this.state.bands.map((b) => ({ ...b })) };
  }

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
