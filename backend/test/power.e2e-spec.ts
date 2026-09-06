import { buildApp, agent, PrismaMock } from './setup';
import { SystemMonitorService } from '../src/modules/notifications/system-monitor.service';
import { POWER_DRIVER } from '../src/modules/power/power.service';
import { PowerDriver, healthyPower } from '../src/modules/power/drivers/power.driver';

/** A driver mock that lets each test programme the health to be served. */
function mockDriver(health: ReturnType<typeof healthyPower>) {
  return {
    kind: 'test',
    getHealth: jest.fn().mockReturnValue(health),
  };
}

describe('PowerController (e2e)', () => {
  it('GET /api/power serves the real module wiring (mock driver, all healthy)', async () => {
    const { app } = await buildApp();
    try {
      const res = await agent(app).get('/api/power');
      expect(res.status).toBe(200);
      expect(res.body).toEqual(healthyPower());
    } finally {
      await app.close();
    }
  });

  it('GET /api/power reflects a substituted undervoltage driver', async () => {
    const driver = mockDriver({
      ...healthyPower(),
      undervoltage: true,
      occurred: { ...healthyPower().occurred, undervoltage: true },
    });
    const { app } = await buildApp([{ provide: POWER_DRIVER, useValue: driver }]);
    try {
      const res = await agent(app).get('/api/power');
      expect(res.status).toBe(200);
      expect(res.body.undervoltage).toBe(true);
      expect(res.body.occurred.undervoltage).toBe(true);
    } finally {
      await app.close();
    }
  });
});

describe('SystemMonitorService.checkPower (e2e, via DI)', () => {
  it('sends a notification when the Pi reports undervoltage', async () => {
    const driver = mockDriver({ ...healthyPower(), undervoltage: true });
    const { app, prisma } = await buildApp([{ provide: POWER_DRIVER, useValue: driver }]);
    try {
      const monitor = app.get(SystemMonitorService, { strict: false });
      // The monitor also checks tasks; give it an empty list so the power
      // alert is the only notification created.
      prisma.task.findMany.mockResolvedValue([]);
      // NotificationsService.send() persists via prisma — give it a record.
      prisma.notification.create.mockResolvedValue({
        id: BigInt(1),
        type: 'warning',
        title: 'x',
        message: null,
        action: null,
        read: false,
        createdAt: new Date(),
      });
      await monitor.runOnce();

      expect(prisma.notification.create).toHaveBeenCalled();
      const data = (prisma.notification.create as jest.Mock).mock.calls[0][0].data;
      expect(data.title).toBe('Subtensión en la Pi');
      expect(data.type).toBe('warning');
    } finally {
      await app.close();
    }
  });

  it('sends a throttle notification but skips when power is unavailable', async () => {
    const unavailable = mockDriver({ ...healthyPower(), available: false });
    const { app, prisma } = await buildApp([{ provide: POWER_DRIVER, useValue: unavailable }]);
    try {
      const monitor = app.get(SystemMonitorService, { strict: false });
      prisma.task.findMany.mockResolvedValue([]);
      await monitor.runOnce();

      // Unavailable → no power alert. (Temp/disk/task checks run but the
      // desktop has no thermal zone at 75°C and df returns real numbers that
      // may vary; assert only on the power alert keys.)
      const calls = (prisma.notification.create as jest.Mock).mock.calls;
      const titles = calls.map((c) => c[0].data.title);
      expect(titles).not.toContain('Subtensión en la Pi');
      expect(titles).not.toContain('CPU limitado (throttle)');
    } finally {
      await app.close();
    }
  });
});