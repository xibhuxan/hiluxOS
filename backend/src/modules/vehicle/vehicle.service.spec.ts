import { MockVehicleDriver } from './drivers/mock-vehicle.driver';

describe('MockVehicleDriver', () => {
  /** Deterministic clock: tests fast-forward time without any timer. */
  class FakeClock {
    now = 1_000_000_000_000;
    read = () => this.now;
    advanceMs(ms: number) {
      this.now += ms;
    }
  }

  const makeDriver = () => {
    const clock = new FakeClock();
    return { driver: new MockVehicleDriver(clock.read), clock };
  };

  const windowById = (s: ReturnType<MockVehicleDriver['getSnapshot']>, id: number) =>
    s.windows.find((w) => w.id === id)!;

  it('reports connected with plausible telemetry bounds', () => {
    const { driver } = makeDriver();
    const s = driver.getSnapshot();

    expect(s.connected).toBe(true);
    expect(s.ignition).toBe(true);
    expect(s.engine.speedKmh).toBeGreaterThanOrEqual(16);
    expect(s.engine.speedKmh).toBeLessThanOrEqual(94);
    expect(s.engine.rpm).toBeGreaterThanOrEqual(1000);
    expect(s.engine.rpm).toBeLessThanOrEqual(3400);
    expect(s.engine.coolantTempC).toBeGreaterThanOrEqual(22);
    expect(s.engine.coolantTempC).toBeLessThanOrEqual(88);
    expect(s.batteryVoltage).toBeGreaterThanOrEqual(13.9);
    expect(s.batteryVoltage).toBeLessThanOrEqual(14.3);
    expect(s.engine.fuelLevel).toBeGreaterThan(0);
    expect(s.engine.fuelLevel).toBeLessThanOrEqual(1);
    expect(s.engine.odometerKm).toBeGreaterThan(0);
  });

  it('warms the engine up over time (exponential approach to 88°C)', () => {
    const { driver, clock } = makeDriver();
    const cold = driver.getSnapshot();
    clock.advanceMs(20 * 60 * 1000); // 20 minutes
    const warm = driver.getSnapshot();

    expect(cold.engine.coolantTempC).not.toBeNull();
    expect(warm.engine.coolantTempC).not.toBeNull();
    expect(cold.engine.coolantTempC!).toBeLessThan(30);
    expect(warm.engine.coolantTempC!).toBeGreaterThan(cold.engine.coolantTempC!);
    expect(warm.engine.coolantTempC!).toBeLessThanOrEqual(88);
  });

  it('evolves telemetry between polls (the card feels alive)', () => {
    const { driver, clock } = makeDriver();
    const a = driver.getSnapshot();
    clock.advanceMs(90 * 1000); // a different point of the sine curves
    const b = driver.getSnapshot();

    expect(b.engine.speedKmh).not.toEqual(a.engine.speedKmh);
    expect(b.engine.odometerKm).not.toBeNull();
    expect(a.engine.odometerKm).not.toBeNull();
    expect(b.engine.odometerKm!).toBeGreaterThanOrEqual(a.engine.odometerKm!);
  });

  it('starts with all lights off and applies partial light updates', () => {
    const { driver } = makeDriver();
    expect(driver.getSnapshot().lights).toEqual({
      position: false,
      low: false,
      high: false,
      fog: false,
      auxiliary: false,
    });

    driver.setLights({ low: true, fog: true });
    expect(driver.getSnapshot().lights).toEqual({
      position: false,
      low: true,
      high: false,
      fog: true,
      auxiliary: false,
    });
  });

  it('hazard cancels indicators, and an indicator cancels hazard', () => {
    const { driver } = makeDriver();

    driver.setTurnSignals({ hazard: true });
    expect(driver.getSnapshot().turnSignals).toEqual({ left: false, right: false, hazard: true });

    driver.setTurnSignals({ left: true });
    expect(driver.getSnapshot().turnSignals).toEqual({ left: true, right: false, hazard: false });

    driver.setTurnSignals({ hazard: true });
    expect(driver.getSnapshot().turnSignals).toEqual({ left: false, right: false, hazard: true });
  });

  it('toggles the central lock', () => {
    const { driver } = makeDriver();
    expect(driver.getSnapshot().centralLock.locked).toBe(false);

    driver.setCentralLock(true);
    expect(driver.getSnapshot().centralLock.locked).toBe(true);

    driver.setCentralLock(false);
    expect(driver.getSnapshot().centralLock.locked).toBe(false);
  });

  it('opens and closes doors by id', () => {
    const { driver } = makeDriver();
    expect(driver.getSnapshot().doors.map((d) => d.open)).toEqual([false, false, false, false]);

    driver.setDoor(1, true);
    driver.setDoor(4, true);
    expect(driver.getSnapshot().doors.map((d) => d.open)).toEqual([true, false, false, true]);

    driver.setDoor(1, false);
    expect(driver.getSnapshot().doors[0].open).toBe(false);
  });

  it('arms and disarms the alarm', () => {
    const { driver } = makeDriver();
    expect(driver.getSnapshot().alarm.armed).toBe(false);

    driver.setAlarm(true);
    expect(driver.getSnapshot().alarm.armed).toBe(true);

    driver.setAlarm(false);
    expect(driver.getSnapshot().alarm.armed).toBe(false);
  });

  describe('ignition', () => {
    it('turning it off parks the car: speed/rpm 0, ignition false, battery at rest', () => {
      const { driver, clock } = makeDriver();
      const driving = driver.getSnapshot();
      expect(driving.ignition).toBe(true);
      expect(driving.engine.speedKmh).toBeGreaterThan(0);

      clock.advanceMs(100);
      driver.setIgnition(false);
      const parked = driver.getSnapshot();
      expect(parked.ignition).toBe(false);
      expect(parked.engine.speedKmh).toBe(0);
      expect(parked.engine.rpm).toBe(0);
      expect(parked.batteryVoltage).toBeLessThan(13); // resting battery, not 14.x alternator
    });

    it('freezes the odometer and fuel while off, then resumes running', () => {
      const { driver, clock } = makeDriver();
      clock.advanceMs(120 * 1000); // 2 minutes driving
      driver.setIgnition(false);
      const offA = driver.getSnapshot();
      clock.advanceMs(600 * 1000); // 10 minutes parked
      const offB = driver.getSnapshot();
      expect(offB.engine.odometerKm).toBe(offA.engine.odometerKm); // frozen
      expect(offB.engine.fuelLevel).toBe(offA.engine.fuelLevel); // frozen
      expect(offB.engine.coolantTempC!).toBeLessThan(offA.engine.coolantTempC!); // cooling down

      driver.setIgnition(true);
      clock.advanceMs(5 * 1000);
      const resumed = driver.getSnapshot();
      expect(resumed.ignition).toBe(true);
      expect(resumed.engine.speedKmh).toBeGreaterThan(0);
      expect(resumed.engine.odometerKm).toBeGreaterThan(offB.engine.odometerKm!); // resumes
    });

    it('idempotent toggles do not drift the running-time accounting', () => {
      const { driver, clock } = makeDriver();
      clock.advanceMs(60 * 1000);
      driver.setIgnition(true); // already on → no-op
      clock.advanceMs(60 * 1000);
      const s = driver.getSnapshot();
      // 2 minutes total running: the odometer reflects the full 2 minutes of
      // the same closed-form curve (linear + both sine integrals).
      const t = 120;
      const expectedKm =
        184320 + (55 * t + 1260 * (1 - Math.cos(t / 45)) + 143 * (1 - Math.cos(t / 13))) / 3600;
      expect(s.engine.odometerKm!).toBeCloseTo(Math.round(expectedKm * 10) / 10, 1);
    });
  });

  describe('power windows', () => {
    it('animates a window down and freezes it at the fully-open position', () => {
      const { driver, clock } = makeDriver();

      driver.windowAction(1, 'down');
      clock.advanceMs(500);
      const mid = windowById(driver.getSnapshot(), 1);
      expect(mid.position).toBeCloseTo(0.25, 2);
      expect(mid.moving).toBe('down');

      clock.advanceMs(1500); // full travel is 2 s
      const end = windowById(driver.getSnapshot(), 1);
      expect(end.position).toBe(1);
      expect(end.moving).toBeNull();
    });

    it('stops mid-travel, stays frozen while stopped, and resumes from there', () => {
      const { driver, clock } = makeDriver();

      driver.windowAction(2, 'down');
      clock.advanceMs(700); // 0.7 s of travel → 0.35
      driver.windowAction(2, 'stop');
      const stopped = windowById(driver.getSnapshot(), 2);
      expect(stopped.moving).toBeNull();
      expect(stopped.position).toBeCloseTo(0.35, 2);

      clock.advanceMs(10 * 1000); // frozen while stopped
      expect(windowById(driver.getSnapshot(), 2).position).toBeCloseTo(stopped.position, 5);

      driver.windowAction(2, 'down');
      clock.advanceMs(1300); // from 0.35, 1.3 s remain to reach 1.0
      expect(windowById(driver.getSnapshot(), 2).position).toBe(1);
    });

    it('animates the window back up and freezes it fully closed', () => {
      const { driver, clock } = makeDriver();

      driver.windowAction(3, 'down');
      clock.advanceMs(2000); // fully open
      driver.windowAction(3, 'up');
      clock.advanceMs(1000);
      expect(windowById(driver.getSnapshot(), 3).moving).toBe('up');

      clock.advanceMs(1000);
      const end = windowById(driver.getSnapshot(), 3);
      expect(end.position).toBe(0);
      expect(end.moving).toBeNull();
    });

    it('ignores requests to keep moving past the end of the travel', () => {
      const { driver, clock } = makeDriver();

      driver.windowAction(4, 'up'); // already closed → no-op
      clock.advanceMs(100);
      const closed = windowById(driver.getSnapshot(), 4);
      expect(closed.position).toBe(0);
      expect(closed.moving).toBeNull();
    });
  });
});