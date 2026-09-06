import { buildApp, agent } from './setup';
import { VEHICLE_DRIVER } from '../src/modules/vehicle/vehicle.service';
import { VehicleDriver, VehicleSnapshot, disconnectedSnapshot } from '../src/modules/vehicle/drivers/vehicle.driver';

/** A driver mock that lets each test programme the snapshot to be served. */
function mockDriver(snapshot: VehicleSnapshot): jest.Mocked<VehicleDriver> {
  return {
    kind: 'test',
    getSnapshot: jest.fn().mockReturnValue(snapshot),
    setLights: jest.fn(),
    setTurnSignals: jest.fn(),
    setCentralLock: jest.fn(),
    setIgnition: jest.fn(),
    setDoor: jest.fn(),
    setAlarm: jest.fn(),
    windowAction: jest.fn(),
  } as unknown as jest.Mocked<VehicleDriver>;
}

/**
 * VehicleController e2e. Uses the REAL VehicleModule (the DI factory resolves
 * HAL_VEHICLE, defaulting to the mock driver) so the wiring is covered too;
 * specific snapshots are injected by overriding the VEHICLE_DRIVER token.
 */
describe('VehicleController (e2e)', () => {
  describe('GET /api/vehicle with the real mock driver (DI factory)', () => {
    it('serves the simulated snapshot', async () => {
      const { app, prisma } = await buildApp();
      try {
        const res = await agent(app).get('/api/vehicle');
        expect(res.status).toBe(200);
        expect(res.body.connected).toBe(true);
        expect(res.body.engine).toMatchObject({
          rpm: expect.any(Number),
          speedKmh: expect.any(Number),
          coolantTempC: expect.any(Number),
        });
        expect(res.body.windows).toHaveLength(4);
        expect(res.body.doors).toHaveLength(4);
        expect(prisma.$queryRaw).not.toHaveBeenCalled();
      } finally {
        await app.close();
      }
    });
  });

  describe('action endpoints', () => {
    let app: Awaited<ReturnType<typeof buildApp>>['app'];
    let driver: jest.Mocked<VehicleDriver>;
    let sample: VehicleSnapshot;

    beforeEach(async () => {
      sample = disconnectedSnapshot();
      driver = mockDriver(sample);
      app = (await buildApp([{ provide: VEHICLE_DRIVER, useValue: driver }])).app;
    });

    afterEach(async () => {
      await app.close();
    });

    it('PUT /api/vehicle/lights applies the partial update and returns the snapshot', async () => {
      driver.getSnapshot.mockReturnValue({ ...sample, connected: true });
      const res = await agent(app).put('/api/vehicle/lights').send({ low: true });
      expect(res.status).toBe(200);
      expect(driver.setLights).toHaveBeenCalledWith({ low: true });
      expect(res.body.connected).toBe(true);
    });

    it('PUT /api/vehicle/signals rejects an unknown field (whitelist)', async () => {
      const res = await agent(app).put('/api/vehicle/signals').send({ left: true, bogus: 1 });
      expect(res.status).toBe(400);
      expect(driver.setTurnSignals).not.toHaveBeenCalled();
    });

    it('PUT /api/vehicle/lock validates locked as boolean', async () => {
      const res = await agent(app).put('/api/vehicle/lock').send({ locked: 'yes' });
      expect(res.status).toBe(400);
      expect(driver.setCentralLock).not.toHaveBeenCalled();

      const ok = await agent(app).put('/api/vehicle/lock').send({ locked: true });
      expect(ok.status).toBe(200);
      expect(driver.setCentralLock).toHaveBeenCalledWith(true);
    });

    it('PUT /api/vehicle/lights rejects an unknown field (whitelist)', async () => {
      const res = await agent(app).put('/api/vehicle/lights').send({ neon: true });
      expect(res.status).toBe(400);
      expect(driver.setLights).not.toHaveBeenCalled();
    });

    it('PUT /api/vehicle/signals applies left=true and returns the snapshot', async () => {
      driver.getSnapshot.mockReturnValue({ ...sample, connected: true });
      const res = await agent(app).put('/api/vehicle/signals').send({ left: true });
      expect(res.status).toBe(200);
      expect(driver.setTurnSignals).toHaveBeenCalledWith({ left: true });
      expect(res.body.connected).toBe(true);
    });

    it('POST /api/vehicle/windows/2/down forwards the action and returns the snapshot', async () => {
      driver.getSnapshot.mockReturnValue({ ...sample, connected: true });
      const res = await agent(app).post('/api/vehicle/windows/2/down');
      expect(res.status).toBe(200);
      expect(driver.windowAction).toHaveBeenCalledWith(2, 'down');
      expect(res.body.connected).toBe(true);
    });

    it('POST /api/vehicle/windows/99/down returns 404 for an unknown window', async () => {
      const res = await agent(app).post('/api/vehicle/windows/99/down');
      expect(res.status).toBe(404);
      expect(driver.windowAction).not.toHaveBeenCalledWith(99, 'down');
    });

    it('PUT /api/vehicle/ignition turns the engine off and also drops the high beams', async () => {
      driver.getSnapshot.mockReturnValue({ ...sample, connected: true, ignition: true });
      const res = await agent(app).put('/api/vehicle/ignition').send({ on: false });
      expect(res.status).toBe(200);
      expect(driver.setIgnition).toHaveBeenCalledWith(false);
      expect(driver.setLights).toHaveBeenCalledWith({ high: false });
      expect(res.body.connected).toBe(true);
    });

    it('PUT /api/vehicle/doors/2 opens the door and returns the snapshot', async () => {
      driver.getSnapshot.mockReturnValue({ ...sample, connected: true });
      const res = await agent(app).put('/api/vehicle/doors/2').send({ open: true });
      expect(res.status).toBe(200);
      expect(driver.setDoor).toHaveBeenCalledWith(2, true);
      expect(res.body.connected).toBe(true);
    });

    it('PUT /api/vehicle/doors/99 returns 404 for an unknown door', async () => {
      const res = await agent(app).put('/api/vehicle/doors/99').send({ open: true });
      expect(res.status).toBe(404);
      expect(driver.setDoor).not.toHaveBeenCalled();
    });

    it('PUT /api/vehicle/alarm arms the anti-theft alarm', async () => {
      driver.getSnapshot.mockReturnValue({ ...sample, connected: true });
      const res = await agent(app).put('/api/vehicle/alarm').send({ armed: true });
      expect(res.status).toBe(200);
      expect(driver.setAlarm).toHaveBeenCalledWith(true);
      expect(res.body.alarm).toEqual({ armed: true });
    });
  });
});