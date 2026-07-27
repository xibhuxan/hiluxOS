import { Injectable } from '@nestjs/common';
import os from 'node:os';
import fs from 'node:fs/promises';
import { execFileSync } from 'node:child_process';

@Injectable()
export class SystemService {
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
  async getTemperature(): Promise<{ celsius: number | null }> {
    try {
      const raw = await fs.readFile('/sys/class/thermal/thermal_zone0/temp', 'utf8');
      return { celsius: parseInt(raw.trim(), 10) / 1000 };
    } catch {
      return { celsius: null };
    }
  }

  /** Free/used space on the root filesystem via df. */
  getDisk(): { freeGb: number | null; usedPercent: number | null } {
    const out = this.run('df', ['-m', '/']);
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

  /** Run a command, returning stdout or null if it fails/unavailable. */
  private run(bin: string, args: string[], timeoutMs = 2000): string | null {
    try {
      return execFileSync(bin, args, {
        encoding: 'utf8',
        timeout: timeoutMs,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch {
      return null;
    }
  }

  /** Run a command, throwing if it fails. */
  private runOrThrow(bin: string, args: string[], timeoutMs = 2000): string {
    return execFileSync(bin, args, {
      encoding: 'utf8',
      timeout: timeoutMs,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  }

  // ---- Audio (wpctl, amixer fallback) ----

  getAudio(): { volume: number | null; muted: boolean | null } {
    const out = this.run('wpctl', ['get-volume', '@DEFAULT_AUDIO_SINK@']);
    if (out !== null) {
      const m = out.match(/Volume:\s*([0-9.]+)(\s*\[MUTED\])?/);
      if (m) {
        return { volume: Math.round(parseFloat(m[1]) * 100), muted: /\[MUTED\]/.test(out) };
      }
    }
    const am = this.run('amixer', ['sget', 'Master']) ?? this.run('amixer', ['sget', 'PCM']);
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
    if (this.run('wpctl', ['set-volume', '@DEFAULT_AUDIO_SINK@', (v / 100).toFixed(3)]) !== null) return;
    this.runOrThrow('amixer', ['sset', 'Master', `${v}%`]);
  }

  setAudioMuted(muted: boolean): void {
    if (this.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', muted ? '1' : '0']) !== null) return;
    this.runOrThrow('amixer', ['sset', 'Master', muted ? 'mute' : 'unmute']);
  }

  // ---- Network (nmcli) ----

  getNetwork(): { wifiEnabled: boolean | null; connected: boolean; ssid: string | null; signal: number | null } {
    const radio = this.run('nmcli', ['-t', '-f', 'WIFI', 'radio']);
    if (radio === null) return { wifiEnabled: null, connected: false, ssid: null, signal: null };
    const wifiEnabled = radio.trim() === 'enabled';

    let ssid: string | null = null;
    let signal: number | null = null;
    if (wifiEnabled) {
      const list = this.run('nmcli', ['-t', '-f', 'ACTIVE,SSID,SIGNAL', 'dev', 'wifi', 'list']);
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
    this.runOrThrow('nmcli', ['radio', 'wifi', enabled ? 'on' : 'off']);
  }

  // ---- Bluetooth (bluetoothctl) ----

  getBluetooth(): { powered: boolean | null; connected: boolean } {
    const out = this.run('bluetoothctl', ['show']);
    if (out === null) return { powered: null, connected: false };
    return {
      powered: /Powered:\s*yes/i.test(out),
      connected: /Connected:\s*yes/i.test(out),
    };
  }

  setBluetooth(powered: boolean): void {
    this.runOrThrow('bluetoothctl', ['power', powered ? 'on' : 'off']);
  }
}