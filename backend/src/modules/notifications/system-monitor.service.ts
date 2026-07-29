import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * Monitors system health and sends notifications automatically:
 *  - High CPU temperature
 *  - Low disk space
 *  - Tasks with high priority that are not done
 *
 * Runs every 5 minutes. Uses the DB to avoid spamming the same notification
 * repeatedly (cooldown tracking).
 */
@Injectable()
export class SystemMonitorService {
  private readonly logger = new Logger(SystemMonitorService.name);
  private readonly cooldownMs = 30 * 60 * 1000; // 30 min between same alerts
  private lastAlerts = new Map<string, number>(); // key -> timestamp

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async checkSystem() {
    this.logger.debug('Running system monitor check...');
    await this.checkTemperature();
    await this.checkDisk();
    await this.checkHighPriorityTasks();
  }

  /** Manual trigger (for testing). */
  async runOnce() {
    await this.checkSystem();
  }

  private async checkTemperature() {
    let celsius: number | null = null;
    try {
      const fs = await import('node:fs');
      const raw = fs.readFileSync('/sys/class/thermal/thermal_zone0/temp', 'utf8');
      celsius = parseInt(raw.trim(), 10) / 1000;
    } catch {
      return; // no thermal zone available (not on a Pi or Linux)
    }

    if (celsius !== null && celsius >= 75) {
      await this.sendIfCool(
        'temp-high',
        {
          type: 'warning',
          title: 'Temperatura alta',
          message: `CPU a ${celsius.toFixed(1)}°C`,
          action: { screen: '/system' },
        },
      );
    }
  }

  private async checkDisk() {
    try {
      const { execFileSync } = await import('node:child_process');
      const out = execFileSync('df', ['-m', '/'], { encoding: 'utf8' });
      const lines = out.trim().split('\n');
      const parts = lines[lines.length - 1].trim().split(/\s+/);
      const usePct = parseInt(parts[4], 10);
      if (!isNaN(usePct) && usePct >= 90) {
        await this.sendIfCool(
          'disk-full',
          {
            type: 'error',
            title: 'Disco casi lleno',
            message: `Uso de disco al ${usePct}%`,
            action: { screen: '/system' },
          },
        );
      }
    } catch {
      // df not available
    }
  }

  private async checkHighPriorityTasks() {
    const tasks = await this.prisma.task.findMany({
      where: { done: false, priority: { gte: 2 } },
      orderBy: { priority: 'desc' },
      take: 1,
    });

    if (tasks.length > 0) {
      const task = tasks[0];
      await this.sendIfCool(
        `task-priority-${task.id}`,
        {
          type: 'info',
          title: 'Tarea prioritaria pendiente',
          message: task.title,
          action: { screen: '/tasks' },
        },
      );
    }
  }

  /** Only send if the same alert key hasn't fired in the last cooldownMs. */
  private async sendIfCool(key: string, dto: {
    type: string;
    title: string;
    message?: string;
    action?: Record<string, unknown>;
  }) {
    const now = Date.now();
    const last = this.lastAlerts.get(key);
    if (last && now - last < this.cooldownMs) return;
    this.lastAlerts.set(key, now);
    await this.notifications.send(dto);
  }
}