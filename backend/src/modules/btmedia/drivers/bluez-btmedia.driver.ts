import { CommandRunner } from '../../system/command-runner';
import { BtMediaDriver, BtMediaState, BtMediaStatus, BtTrack, clampBtVolume, emptyBtMediaState } from './btmedia.driver';

/**
 * Real Bluetooth media on BlueZ, parsed from `bluetoothctl`.
 *
 * Strategy (best-effort):
 *  - Availability: a BT adapter exists and is powered on.
 *  - Connection: `bluetoothctl devices Connected` lists at least one device.
 *  - Metadata/status: `bluetoothctl player.show` exposes AVRCP track info and
 *    playback status on BlueZ ≥ 5.65 (via the org.bluez.MediaPlayer1 D-Bus
 *    interface). Older BlueZ exposes nothing here, so track stays null.
 *  - Actions: `bluetoothctl player.play|pause|next|previous` (AVRCP
 *    passthrough). Volume is tracked locally (absolute A2DP volume via
 *    bluetoothctl is not exposed pre-5.65); it still clamps and persists.
 *
 * ⚠️  REQUIRES VALIDATION ON REAL HARDWARE (Raspberry Pi + phone). The exact
 * `bluetoothctl` output format varies across BlueZ versions; the parsers below
 * are deliberately tolerant (regex, missing-field → null) and the whole driver
 * degrades to `available:false` (mirroring RpiPowerDriver) whenever the
 * adapter/daemon is missing. The routing fine-tuning is validated on the Pi.
 */
export class BluezBtMediaDriver extends BtMediaDriver {
  readonly kind = 'bluez';
  private state: BtMediaState = emptyBtMediaState(false);

  constructor(private readonly cmd: CommandRunner) {
    super();
  }

  getState(): BtMediaState {
    this.refresh();
    return this.copy();
  }

  play(): BtMediaState {
    this.cmd.run('bluetoothctl', ['player.play']);
    return this.mutate(() => {
      if (this.state.connected) this.state.status = 'playing';
    });
  }

  pause(): BtMediaState {
    this.cmd.run('bluetoothctl', ['player.pause']);
    return this.mutate(() => {
      if (this.state.connected) this.state.status = 'paused';
    });
  }

  next(): BtMediaState {
    this.cmd.run('bluetoothctl', ['player.next']);
    return this.mutate(() => this.resetPosition());
  }

  previous(): BtMediaState {
    this.cmd.run('bluetoothctl', ['player.previous']);
    return this.mutate(() => this.resetPosition());
  }

  setVolume(volume: number): BtMediaState {
    // Local absolute volume (A2DP absolute volume over bluetoothctl is only
    // exposed on newer BlueZ); clamp + track so the UI stays consistent.
    this.state.volume = clampBtVolume(volume);
    return this.getState();
  }

  // ---- BlueZ plumbing ----

  /** Apply a mutation, then re-read the live state. */
  private mutate(fn: () => void): BtMediaState {
    fn();
    return this.getState();
  }

  private resetPosition(): void {
    if (this.state.track) this.state.track = { ...this.state.track, positionSec: 0 };
  }

  /** Is a BT adapter present and powered on? */
  private adapterAvailable(): boolean {
    const show = this.cmd.run('bluetoothctl', ['show']);
    if (!show) return false;
    return /Powered:\s*yes/i.test(show);
  }

  /** Re-read the live state from bluetoothctl, degrading gracefully. */
  private refresh(): void {
    if (!this.adapterAvailable()) {
      this.state = emptyBtMediaState(false);
      return;
    }

    const devices = this.cmd.run('bluetoothctl', ['devices', 'Connected']) ?? '';
    const first = this.parseFirstConnected(devices);
    if (!first) {
      this.state = { ...emptyBtMediaState(true), volume: this.state.volume };
      return;
    }

    const player = this.cmd.run('bluetoothctl', ['player.show']) ?? '';
    const track = this.parseTrack(player);
    const status = this.parseStatus(player);

    this.state = {
      available: true,
      connected: true,
      deviceName: first.name,
      track,
      status: status ?? (track ? 'paused' : 'stopped'),
      volume: this.state.volume,
    };
  }

  /** Parse the first connected device out of `bluetoothctl devices Connected`. */
  private parseFirstConnected(out: string): { mac: string; name: string } | null {
    // Lines look like: "Device AA:BB:CC:DD:EE:FF Pixel 8 Pro"
    const m = /^Device\s+([0-9A-F:]{17})\s+(.+)$/im.exec(out);
    if (!m) return null;
    return { mac: m[1], name: m[2].trim() };
  }

  /** Parse AVRCP track metadata out of `bluetoothctl player.show`. */
  private parseTrack(out: string): BtTrack | null {
    if (!out) return null;
    const get = (key: string): string | null => {
      const m = new RegExp(`^\\s*${key}:\\s*(.+)$`, 'im').exec(out);
      return m ? m[1].trim() : null;
    };
    const title = get('Title');
    if (!title) return null; // no player / no track
    const durationMs = parseInt(get('Duration') ?? '0', 10);
    const positionMs = parseInt(get('Position') ?? '0', 10);
    return {
      title,
      artist: get('Artist') ?? 'Desconocido',
      album: get('Album') ?? 'Desconocido',
      durationSec: Number.isFinite(durationMs) && durationMs > 0 ? Math.round(durationMs / 1000) : 0,
      positionSec: Number.isFinite(positionMs) && positionMs > 0 ? Math.floor(positionMs / 1000) : 0,
    };
  }

  /** Parse AVRCP playback status out of `bluetoothctl player.show`. */
  private parseStatus(out: string): BtMediaStatus | null {
    const m = /^\s*Status:\s*(.+)$/im.exec(out);
    if (!m) return null;
    const s = m[1].trim().toLowerCase();
    if (s === 'playing') return 'playing';
    if (s === 'paused') return 'paused';
    return 'stopped';
  }

  private copy(): BtMediaState {
    return {
      ...this.state,
      track: this.state.track ? { ...this.state.track } : null,
    };
  }
}
