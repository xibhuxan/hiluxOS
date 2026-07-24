import { Injectable } from '@nestjs/common';
import os from 'node:os';
import fs from 'node:fs/promises';

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
}