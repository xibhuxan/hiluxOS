import { buildApp, agent } from './setup';
import { SystemService } from '../src/modules/system/system.service';

/** A fully-mocked SystemService so the e2e never spawns nmcli/bluetoothctl. */
function mockSystem(): jest.Mocked<SystemService> {
  return {
    getInfo: jest.fn().mockReturnValue({ hostname: 'pi' }),
    getResources: jest.fn().mockReturnValue({ memoryUsagePercent: 10 }),
    getTemperature: jest.fn().mockReturnValue({ celsius: 42 }),
    getDisk: jest.fn().mockReturnValue({ freeGb: 5, usedPercent: 50 }),
    checkInternet: jest.fn().mockResolvedValue({ reachable: true, latencyMs: 12 }),
    getAudio: jest.fn().mockReturnValue({ volume: 50, muted: false }),
    setAudioVolume: jest.fn(),
    setAudioMuted: jest.fn(),
    getNetwork: jest
      .fn()
      .mockReturnValue({ wifiEnabled: true, connected: true, ssid: 'HomeNet', signal: 84 }),
    setWifi: jest.fn(),
    getBluetooth: jest.fn().mockReturnValue({ powered: true, connected: false }),
    setBluetooth: jest.fn(),
    getBrightness: jest.fn().mockReturnValue({ brightness: 60, maxBrightness: 255 }),
    setBrightness: jest.fn(),
    scanWifi: jest.fn().mockReturnValue([
      { ssid: 'HomeNet', signal: 84, secure: true, inRange: true },
      { ssid: 'Cafe', signal: 40, secure: false, inRange: false },
    ]),
    connectWifi: jest.fn(),
    disconnectWifi: jest.fn(),
    forgetWifi: jest.fn(),
    scanBluetooth: jest.fn().mockReturnValue([
      { mac: 'AA:BB:CC:DD:EE:FF', name: 'Headphones', paired: true, connected: false },
    ]),
    pairBluetooth: jest.fn(),
    connectBluetooth: jest.fn(),
    disconnectBluetooth: jest.fn(),
    removeBluetooth: jest.fn(),
  } as unknown as jest.Mocked<SystemService>;
}

describe('SystemController (e2e) - network & bluetooth', () => {
  let app: Awaited<ReturnType<typeof buildApp>>;
  let system: jest.Mocked<SystemService>;

  beforeEach(async () => {
    system = mockSystem();
    app = await buildApp([{ provide: SystemService, useValue: system }]);
  });

  afterEach(async () => {
    await app.app.close();
  });

  describe('GET /api/system/network/wifi/scan', () => {
    it('returns the scanned networks', async () => {
      const res = await agent(app.app).get('/api/system/network/wifi/scan');
      expect(res.status).toBe(200);
      expect(res.body).toEqual([
        { ssid: 'HomeNet', signal: 84, secure: true, inRange: true },
        { ssid: 'Cafe', signal: 40, secure: false, inRange: false },
      ]);
      expect(system.scanWifi).toHaveBeenCalled();
    });
  });

  describe('POST /api/system/network/wifi/connect', () => {
    it('connects with a password and returns the updated network state', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/wifi/connect')
        .send({ ssid: 'HomeNet', password: 'secret' });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ wifiEnabled: true, connected: true, ssid: 'HomeNet', signal: 84 });
      expect(system.connectWifi).toHaveBeenCalledWith('HomeNet', 'secret');
    });

    it('connects without a password (stored connection)', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/wifi/connect')
        .send({ ssid: 'HomeNet' });

      expect(res.status).toBe(200);
      expect(system.connectWifi).toHaveBeenCalledWith('HomeNet', undefined);
    });

    it('returns 400 when ssid is missing', async () => {
      const res = await agent(app.app).post('/api/system/network/wifi/connect').send({});
      expect(res.status).toBe(400);
      expect(system.connectWifi).not.toHaveBeenCalled();
    });
  });

  describe('POST /api/system/network/wifi/forget', () => {
    it('forgets the network by ssid', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/wifi/forget')
        .send({ ssid: 'HomeNet' });

      expect(res.status).toBe(200);
      expect(system.forgetWifi).toHaveBeenCalledWith('HomeNet');
    });

    it('returns 400 when ssid is missing', async () => {
      const res = await agent(app.app).post('/api/system/network/wifi/forget').send({});
      expect(res.status).toBe(400);
    });
  });

  describe('GET /api/system/network/bluetooth/scan', () => {
    it('returns the scanned devices', async () => {
      const res = await agent(app.app).get('/api/system/network/bluetooth/scan');
      expect(res.status).toBe(200);
      expect(res.body).toEqual([
        { mac: 'AA:BB:CC:DD:EE:FF', name: 'Headphones', paired: true, connected: false },
      ]);
      expect(system.scanBluetooth).toHaveBeenCalled();
    });
  });

  describe('POST /api/system/network/bluetooth/pair', () => {
    it('pairs with a pin and returns the updated scan', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/bluetooth/pair')
        .send({ mac: 'AA:BB:CC:DD:EE:FF', pin: '1234' });

      expect(res.status).toBe(200);
      expect(system.pairBluetooth).toHaveBeenCalledWith('AA:BB:CC:DD:EE:FF', '1234');
    });

    it('pairs without a pin', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/bluetooth/pair')
        .send({ mac: 'AA:BB:CC:DD:EE:FF' });

      expect(res.status).toBe(200);
      expect(system.pairBluetooth).toHaveBeenCalledWith('AA:BB:CC:DD:EE:FF', undefined);
    });

    it('returns 400 when the mac is malformed', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/bluetooth/pair')
        .send({ mac: 'not-a-mac' });

      expect(res.status).toBe(400);
      expect(system.pairBluetooth).not.toHaveBeenCalled();
    });
  });

  describe('POST /api/system/network/bluetooth/connect', () => {
    it('connects to a paired device', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/bluetooth/connect')
        .send({ mac: 'AA:BB:CC:DD:EE:FF' });

      expect(res.status).toBe(200);
      expect(system.connectBluetooth).toHaveBeenCalledWith('AA:BB:CC:DD:EE:FF');
    });
  });

  describe('POST /api/system/network/bluetooth/remove', () => {
    it('removes a paired device', async () => {
      const res = await agent(app.app)
        .post('/api/system/network/bluetooth/remove')
        .send({ mac: 'AA:BB:CC:DD:EE:FF' });

      expect(res.status).toBe(200);
      expect(system.removeBluetooth).toHaveBeenCalledWith('AA:BB:CC:DD:EE:FF');
    });
  });
});