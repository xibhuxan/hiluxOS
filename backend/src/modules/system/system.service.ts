import { Injectable } from '@nestjs/common';
import os from 'node:os';
import fs from 'node:fs';
import { CommandRunner } from './command-runner';

/** A discovered Wi-Fi network. */
export interface WifiNetwork {
  ssid: string;
  signal: number;
  secure: boolean;
  inRange: boolean;
}

/** A discovered Bluetooth device. */
export interface BluetoothDevice {
  mac: string;
  name: string;
  paired: boolean;
  connected: boolean;
}

@Injectable()
export class SystemService {
  constructor(private readonly cmd: CommandRunner) {}

  /** Static system identity info. */
  getInfo() {
    return {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      release: os.release(),
      type: os.type(),
      cpus: os.cpus().length,
      totalMemoryMb: Math.round((os.totalmem() / 1024 / 1024) * 100) / 100,
      uptimeSeconds: Math.round(os.uptime()),
    };
  }

  /** Live resource usage (CPU load, free memory, load averages). */
  getResources() {
    const load = os.loadavg();
    return {
      uptimeSeconds: Math.round(os.uptime()),
      freeMemoryMb: Math.round((os.freemem() / 1024 / 1024) * 100) / 100,
      totalMemoryMb: Math.round((os.totalmem() / 1024 / 1024) * 100) / 100,
      memoryUsagePercent: Math.round(((os.totalmem() - os.freemem()) / os.totalmem()) * 1000) / 10,
      loadAverage: {
        '1m': load[0],
        '5m': load[1],
        '15m': load[2],
      },
      cpuCount: os.cpus().length,
    };
  }

  /** Read temperature from the first available thermal zone (Linux/RPi). */
  getTemperature(): { celsius: number | null } {
    try {
      const raw = fs.readFileSync('/sys/class/thermal/thermal_zone0/temp', 'utf8');
      return { celsius: parseInt(raw.trim(), 10) / 1000 };
    } catch {
      return { celsius: null };
    }
  }

  /** Free/used space on the root filesystem via df. */
  getDisk(): { freeGb: number | null; usedPercent: number | null } {
    const out = this.cmd.run('df', ['-m', '/']);
    if (!out) return { freeGb: null, usedPercent: null };
    const lines = out.trim().split('\n');
    const parts = lines[lines.length - 1].trim().split(/\s+/);
    // Filesystem 1M-blocks Used Available Use% Mounted
    const freeMb = parts[3] ? parseInt(parts[3], 10) : NaN;
    const usePct = parts[4] ? parseInt(parts[4], 10) : NaN;
    return {
      freeGb: isNaN(freeMb) ? null : Math.round((freeMb / 1024) * 10) / 10,
      usedPercent: isNaN(usePct) ? null : usePct,
    };
  }

  // ---- Internet connectivity ----

  /** Check internet reachability via a lightweight HEAD request. */
  async checkInternet(): Promise<{ reachable: boolean; latencyMs: number | null }> {
    const start = Date.now();
    try {
      const res = await fetch('https://1.1.1.1', { method: 'HEAD', signal: AbortSignal.timeout(3000) });
      return { reachable: res.ok, latencyMs: Date.now() - start };
    } catch {
      return { reachable: false, latencyMs: null };
    }
  }

  // ---- Hardware control helpers ----
  // Command execution is delegated to CommandRunner (injectable, mockable).

  // ---- Audio (wpctl, amixer fallback) ----

  getAudio(): { volume: number | null; muted: boolean | null } {
    const out = this.cmd.run('wpctl', ['get-volume', '@DEFAULT_AUDIO_SINK@']);
    if (out !== null) {
      const m = out.match(/Volume:\s*([0-9.]+)(\s*\[MUTED\])?/);
      if (m) {
        return { volume: Math.round(parseFloat(m[1]) * 100), muted: /\[MUTED\]/.test(out) };
      }
    }
    const am = this.cmd.run('amixer', ['sget', 'Master']) ?? this.cmd.run('amixer', ['sget', 'PCM']);
    if (am) {
      const m = am.match(/\[(\d{1,3})%\]/);
      return {
        volume: m ? parseInt(m[1], 10) : null,
        muted: /\[(off|mute)\]/i.test(am),
      };
    }
    return { volume: null, muted: null };
  }

  setAudioVolume(pct: number): void {
    const v = Math.max(0, Math.min(100, Math.round(pct)));
    if (this.cmd.run('wpctl', ['set-volume', '@DEFAULT_AUDIO_SINK@', (v / 100).toFixed(3)]) !== null) return;
    this.cmd.runOrThrow('amixer', ['sset', 'Master', `${v}%`]);
  }

  setAudioMuted(muted: boolean): void {
    if (this.cmd.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', muted ? '1' : '0']) !== null) return;
    this.cmd.runOrThrow('amixer', ['sset', 'Master', muted ? 'mute' : 'unmute']);
  }

  // ---- Network (nmcli) ----

  getNetwork(): { wifiEnabled: boolean | null; connected: boolean; ssid: string | null; signal: number | null } {
    const radio = this.cmd.run('nmcli', ['-t', '-f', 'WIFI', 'radio']);
    if (radio === null) return { wifiEnabled: null, connected: false, ssid: null, signal: null };
    const wifiEnabled = radio.trim() === 'enabled';

    let ssid: string | null = null;
    let signal: number | null = null;
    if (wifiEnabled) {
      const list = this.cmd.run('nmcli', ['-t', '-f', 'ACTIVE,SSID,SIGNAL', 'dev', 'wifi', 'list']);
      if (list) {
        for (const line of list.split('\n')) {
          if (line.startsWith('yes:')) {
            const parts = line.split(':');
            ssid = parts[1] || null;
            signal = parts[2] ? parseInt(parts[2], 10) : null;
            break;
          }
        }
      }
    }
    return { wifiEnabled, connected: ssid !== null, ssid, signal };
  }

  setWifi(enabled: boolean): void {
    this.cmd.runOrThrow('nmcli', ['radio', 'wifi', enabled ? 'on' : 'off']);
  }

  // ---- Bluetooth (bluetoothctl) ----

  getBluetooth(): { powered: boolean | null; connected: boolean } {
    const out = this.cmd.run('bluetoothctl', ['show']);
    if (out === null) return { powered: null, connected: false };
    return {
      powered: /Powered:\s*yes/i.test(out),
      connected: /Connected:\s*yes/i.test(out),
    };
  }

  setBluetooth(powered: boolean): void {
    this.cmd.runOrThrow('bluetoothctl', ['power', powered ? 'on' : 'off']);
  }

  // ---- Brightness (sysfs backlight) ----

  /**
   * Resolve the active backlight sysfs directory once and cache it. Scans
   * `/sys/class/backlight/*` so it works on any hardware (intel_backlight on
   * laptops, rpi_backlight on the Pi, ...). Returns null when no backlight is
   * present, in which case the brightness getters degrade gracefully.
   */
  private get backlightDir(): string | null {
    if (this._backlightDir !== undefined) return this._backlightDir;
    try {
      const entries = fs.readdirSync('/sys/class/backlight');
      this._backlightDir = entries.length ? `/sys/class/backlight/${entries[0]}` : null;
    } catch {
      this._backlightDir = null;
    }
    return this._backlightDir;
  }
  private _backlightDir: string | null | undefined;

  getBrightness(): { brightness: number | null; maxBrightness: number | null } {
    const dir = this.backlightDir;
    if (!dir) return { brightness: null, maxBrightness: null };
    const raw = this.cmd.run('cat', [`${dir}/brightness`]);
    const maxRaw = this.cmd.run('cat', [`${dir}/max_brightness`]);
    if (raw === null || maxRaw === null) return { brightness: null, maxBrightness: null };
    const current = parseInt(raw.trim(), 10);
    const max = parseInt(maxRaw.trim(), 10);
    if (isNaN(current) || isNaN(max) || max === 0) return { brightness: null, maxBrightness: null };
    return { brightness: Math.round((current / max) * 100), maxBrightness: max };
  }

  setBrightness(pct: number | undefined): void {
    if (pct === undefined) return;
    const dir = this.backlightDir;
    if (!dir) return;
    const maxRaw = this.cmd.run('cat', [`${dir}/max_brightness`]);
    if (maxRaw === null) return;
    const max = parseInt(maxRaw.trim(), 10);
    if (isNaN(max) || max === 0) return;
    const target = Math.round((Math.max(0, Math.min(100, pct)) / 100) * max);
    try {
      fs.writeFileSync(`${dir}/brightness`, `${target}\n`);
    } catch (err) {
      console.error(`[system] Failed to write brightness: ${err}`);
    }
  }

  // ---- Wi-Fi scan / connect / forget (nmcli) ----

  /**
   * Scan nearby Wi-Fi networks. Returns a deduplicated list ordered by signal
   * strength (descending). Returns an empty array when nmcli is unavailable.
   */
  scanWifi(): WifiNetwork[] {
    // `nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list` produces colon-
    // separated lines: `MyNet:84:wpa2: `. SSIDs containing colons are escaped
    // as `\:` so we split on unescaped colons only.
    const out = this.cmd.run('nmcli', [
      '-t',
      '-f',
      'SSID,SIGNAL,SECURITY,IN-USE',
      'dev',
      'wifi',
      'list',
    ]);
    if (!out) return [];
    const seen = new Set<string>();
    const nets: WifiNetwork[] = [];
    for (const line of out.trim().split('\n')) {
      if (!line) continue;
      const parts = line.split(/(?<!\\):/).map((p) => p.replace(/\\:/g, ':'));
      const ssid = (parts[0] ?? '').trim();
      if (!ssid || seen.has(ssid)) continue;
      seen.add(ssid);
      nets.push({
        ssid,
        signal: parts[1] ? parseInt(parts[1], 10) : 0,
        secure: !!parts[2] && parts[2].length > 0,
        inRange: parts[3]?.trim() === '*',
      });
    }
    return nets.sort((a, b) => b.signal - a.signal);
  }

  /**
   * Connect to a Wi-Fi network. When `password` is omitted, nmcli tries the
   * already-stored connection (useful for re-connecting to a known network).
   * Throws on failure (caller maps to HTTP error).
   */
  connectWifi(ssid: string, password?: string): void {
    const args = password
      ? ['device', 'wifi', 'connect', ssid, 'password', password]
      : ['connection', 'up', ssid];
    this.cmd.runOrThrow('nmcli', args, 15000);
  }

  /** Disconnect the active Wi-Fi connection. */
  disconnectWifi(): void {
    this.cmd.runOrThrow('nmcli', ['device', 'disconnect', 'wlan0'], 5000);
  }

  /** Forget (delete) a saved Wi-Fi connection by SSID. */
  forgetWifi(ssid: string): void {
    this.cmd.runOrThrow('nmcli', ['connection', 'delete', ssid], 5000);
  }

  // ---- Bluetooth scan / pair / connect / remove (bluetoothctl) ----

  /**
   * Scan for nearby Bluetooth devices. bluetoothctl scan is asynchronous; this
   * triggers a short scan then reads `devices` and `info <mac>` for each.
   * Returns an empty array when bluetoothctl is unavailable.
   */
  scanBluetooth(): BluetoothDevice[] {
    if (this.cmd.run('bluetoothctl', ['show']) === null) return [];
    // A 3-second scan is enough for a kiosk that stays on the screen.
    this.cmd.run('bluetoothctl', ['--timeout', '3', 'scan', 'on'], 5000);
    const list = this.cmd.run('bluetoothctl', ['devices']);
    if (!list) return [];
    const devices: BluetoothDevice[] = [];
    for (const line of list.trim().split('\n')) {
      // `Device AA:BB:CC:DD:EE:FF Headphones`
      const m = /^Device\s+([0-9A-Fa-f:]{17})\s+(.*)$/.exec(line.trim());
      if (!m) continue;
      const mac = m[1];
      const name = m[2].trim();
      const info = this.cmd.run('bluetoothctl', ['info', mac]) ?? '';
      devices.push({
        mac,
        name,
        paired: /Paired:\s*yes/i.test(info),
        connected: /Connected:\s*yes/i.test(info),
      });
    }
    return devices;
  }

  /**
   * Pair a Bluetooth device. For SSPE devices a PIN is exchanged; when `pin`
   * is provided it is fed to bluetoothctl via stdin.
   */
  pairBluetooth(mac: string, pin?: string): void {
    if (pin) {
      // bluetoothctl reads the PIN from stdin during pairing.
      this.cmd.runOrThrow('bluetoothctl', ['pair', mac], 30000, `${pin}\n`);
    } else {
      this.cmd.runOrThrow('bluetoothctl', ['pair', mac], 30000);
    }
  }

  /** Connect to an already-paired Bluetooth device. */
  connectBluetooth(mac: string): void {
    this.cmd.runOrThrow('bluetoothctl', ['connect', mac], 15000);
  }

  /** Disconnect a connected Bluetooth device. */
  disconnectBluetooth(mac: string): void {
    this.cmd.runOrThrow('bluetoothctl', ['disconnect', mac], 10000);
  }

  /** Remove (unpair) a paired Bluetooth device. */
  removeBluetooth(mac: string): void {
    this.cmd.runOrThrow('bluetoothctl', ['remove', mac], 10000);
  }
}
