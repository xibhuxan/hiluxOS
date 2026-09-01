import { SystemService, WifiNetwork, BluetoothDevice } from './system.service';
import { CommandRunner } from './command-runner';
import fs from 'node:fs';

/**
 * A fake CommandRunner that returns scripted stdout keyed by the joined
 * command string. Lets us drive nmcli/bluetoothctl parsing without spawning
 * real processes.
 */
function fakeRunner(scripts: Record<string, string | null>): CommandRunner {
  const runner = {
    run: jest.fn((bin: string, args: string[]) => {
      const key = [bin, ...args].join(' ');
      return scripts[key] ?? null;
    }),
    runOrThrow: jest.fn(
      (bin: string, args: string[], _timeoutMs = 2000, _stdin?: string) => {
        const key = [bin, ...args].join(' ');
        const out = scripts[key];
        if (out === null || out === undefined) throw new Error(`${bin} failed`);
        return out;
      },
    ),
  };
  return runner as unknown as CommandRunner;
}

describe('SystemService', () => {
  const makeService = (runner: CommandRunner) => new SystemService(runner);

  describe('getNetwork', () => {
    it('returns wifi disabled when nmcli says disabled', () => {
      const runner = fakeRunner({ 'nmcli -t -f WIFI radio': 'disabled' });
      expect(makeService(runner).getNetwork()).toEqual({
        wifiEnabled: false,
        connected: false,
        ssid: null,
        signal: null,
      });
    });

    it('parses the active network from the wifi list', () => {
      const runner = fakeRunner({
        'nmcli -t -f WIFI radio': 'enabled',
        'nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list': 'yes:HomeNet:84\nno:Other:30',
      });
      expect(makeService(runner).getNetwork()).toEqual({
        wifiEnabled: true,
        connected: true,
        ssid: 'HomeNet',
        signal: 84,
      });
    });

    it('returns nulls when nmcli is unavailable', () => {
      const runner = fakeRunner({});
      expect(makeService(runner).getNetwork()).toEqual({
        wifiEnabled: null,
        connected: false,
        ssid: null,
        signal: null,
      });
    });
  });

  describe('scanWifi', () => {
    it('parses, dedupes and orders networks by signal desc', () => {
      const runner = fakeRunner({
        'nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list':
          'HomeNet:84:wpa2:*\nCafe:40:: \nHomeNet:84:wpa2:*\nOpenNet:60::',
      });
      const nets = makeService(runner).scanWifi();
      expect(nets).toEqual<WifiNetwork[]>([
        { ssid: 'HomeNet', signal: 84, secure: true, inRange: true },
        { ssid: 'OpenNet', signal: 60, secure: false, inRange: false },
        { ssid: 'Cafe', signal: 40, secure: false, inRange: false },
      ]);
    });

    it('returns an empty array when nmcli is unavailable', () => {
      const runner = fakeRunner({});
      expect(makeService(runner).scanWifi()).toEqual([]);
    });

    it('handles SSIDs that contain escaped colons', () => {
      const runner = fakeRunner({
        'nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list': 'My\\:Net:70:wpa2:',
      });
      const nets = makeService(runner).scanWifi();
      expect(nets).toHaveLength(1);
      expect(nets[0].ssid).toBe('My:Net');
    });
  });

  describe('connectWifi', () => {
    it('calls nmcli with the password when provided', () => {
      const runner = fakeRunner({ 'nmcli device wifi connect HomeNet password secret': '' });
      makeService(runner).connectWifi('HomeNet', 'secret');
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'nmcli',
        ['device', 'wifi', 'connect', 'HomeNet', 'password', 'secret'],
        15000,
      );
    });

    it('falls back to bringing up the stored connection when no password', () => {
      const runner = fakeRunner({ 'nmcli connection up HomeNet': '' });
      makeService(runner).connectWifi('HomeNet');
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'nmcli',
        ['connection', 'up', 'HomeNet'],
        15000,
      );
    });
  });

  describe('forgetWifi', () => {
    it('deletes the stored connection by ssid', () => {
      const runner = fakeRunner({ 'nmcli connection delete HomeNet': '' });
      makeService(runner).forgetWifi('HomeNet');
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'nmcli',
        ['connection', 'delete', 'HomeNet'],
        5000,
      );
    });
  });

  describe('getBluetooth', () => {
    it('parses powered/connected from bluetoothctl show', () => {
      const runner = fakeRunner({ 'bluetoothctl show': 'Powered: yes\nConnected: no\n' });
      expect(makeService(runner).getBluetooth()).toEqual({ powered: true, connected: false });
    });

    it('returns nulls when bluetoothctl is unavailable', () => {
      const runner = fakeRunner({});
      expect(makeService(runner).getBluetooth()).toEqual({ powered: null, connected: false });
    });
  });

  describe('scanBluetooth', () => {
    it('parses devices and their paired/connected state', () => {
      const runner = fakeRunner({
        'bluetoothctl show': 'Powered: yes\n',
        'bluetoothctl --timeout 3 scan on': '',
        'bluetoothctl devices':
          'Device AA:BB:CC:DD:EE:FF Headphones\nDevice 11:22:33:44:55:66 Speaker',
        'bluetoothctl info AA:BB:CC:DD:EE:FF': 'Paired: yes\nConnected: yes',
        'bluetoothctl info 11:22:33:44:55:66': 'Paired: no\nConnected: no',
      });
      const devices = makeService(runner).scanBluetooth();
      expect(devices).toEqual<BluetoothDevice[]>([
        { mac: 'AA:BB:CC:DD:EE:FF', name: 'Headphones', paired: true, connected: true },
        { mac: '11:22:33:44:55:66', name: 'Speaker', paired: false, connected: false },
      ]);
    });

    it('returns an empty array when bluetoothctl is unavailable', () => {
      const runner = fakeRunner({});
      expect(makeService(runner).scanBluetooth()).toEqual([]);
    });
  });

  describe('pairBluetooth', () => {
    it('feeds the pin via stdin when provided', () => {
      const runner = fakeRunner({ 'bluetoothctl pair AA:BB:CC:DD:EE:FF': '' });
      makeService(runner).pairBluetooth('AA:BB:CC:DD:EE:FF', '1234');
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'bluetoothctl',
        ['pair', 'AA:BB:CC:DD:EE:FF'],
        30000,
        '1234\n',
      );
    });

    it('pairs without stdin when no pin', () => {
      const runner = fakeRunner({ 'bluetoothctl pair AA:BB:CC:DD:EE:FF': '' });
      makeService(runner).pairBluetooth('AA:BB:CC:DD:EE:FF');
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'bluetoothctl',
        ['pair', 'AA:BB:CC:DD:EE:FF'],
        30000,
      );
    });
  });

  describe('connectBluetooth / disconnectBluetooth / removeBluetooth', () => {
    it('issues the right bluetoothctl commands', () => {
      const runner = fakeRunner({
        'bluetoothctl connect AA:BB:CC:DD:EE:FF': '',
        'bluetoothctl disconnect AA:BB:CC:DD:EE:FF': '',
        'bluetoothctl remove AA:BB:CC:DD:EE:FF': '',
      });
      const svc = makeService(runner);
      svc.connectBluetooth('AA:BB:CC:DD:EE:FF');
      svc.disconnectBluetooth('AA:BB:CC:DD:EE:FF');
      svc.removeBluetooth('AA:BB:CC:DD:EE:FF');
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'bluetoothctl',
        ['connect', 'AA:BB:CC:DD:EE:FF'],
        15000,
      );
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'bluetoothctl',
        ['disconnect', 'AA:BB:CC:DD:EE:FF'],
        10000,
      );
      expect(runner.runOrThrow).toHaveBeenCalledWith(
        'bluetoothctl',
        ['remove', 'AA:BB:CC:DD:EE:FF'],
        10000,
      );
    });
  });

  describe('setWifi / setBluetooth', () => {
    it('toggles wifi radio via nmcli', () => {
      const runner = fakeRunner({ 'nmcli radio wifi on': '' });
      makeService(runner).setWifi(true);
      expect(runner.runOrThrow).toHaveBeenCalledWith('nmcli', ['radio', 'wifi', 'on']);
    });

    it('toggles bluetooth power via bluetoothctl', () => {
      const runner = fakeRunner({ 'bluetoothctl power off': '' });
      makeService(runner).setBluetooth(false);
      expect(runner.runOrThrow).toHaveBeenCalledWith('bluetoothctl', ['power', 'off']);
    });
  });

  describe('brightness', () => {
    let readdirSpy: jest.SpyInstance;
    let writeSpy: jest.SpyInstance;

    afterEach(() => {
      readdirSpy?.mockRestore();
      writeSpy?.mockRestore();
    });

    it('reads the brightness percentage from the detected backlight', () => {
      readdirSpy = jest.spyOn(fs, 'readdirSync').mockReturnValue(['intel_backlight'] as never);
      const runner = fakeRunner({
        'cat /sys/class/backlight/intel_backlight/brightness': '31200\n',
        'cat /sys/class/backlight/intel_backlight/max_brightness': '120000\n',
      });
      expect(makeService(runner).getBrightness()).toEqual({ brightness: 26, maxBrightness: 120000 });
    });

    it('writes the scaled value to the detected backlight path', () => {
      readdirSpy = jest.spyOn(fs, 'readdirSync').mockReturnValue(['rpi_backlight'] as never);
      writeSpy = jest.spyOn(fs, 'writeFileSync').mockImplementation(() => undefined);
      const runner = fakeRunner({
        'cat /sys/class/backlight/rpi_backlight/max_brightness': '255\n',
      });
      makeService(runner).setBrightness(50);
      expect(writeSpy).toHaveBeenCalledWith(
        '/sys/class/backlight/rpi_backlight/brightness',
        '128\n',
      );
    });

    it('returns nulls when no backlight device is present', () => {
      readdirSpy = jest.spyOn(fs, 'readdirSync').mockReturnValue([] as never);
      const runner = fakeRunner({});
      expect(makeService(runner).getBrightness()).toEqual({ brightness: null, maxBrightness: null });
    });

    it('is a no-op when no backlight device is present', () => {
      readdirSpy = jest.spyOn(fs, 'readdirSync').mockReturnValue([] as never);
      writeSpy = jest.spyOn(fs, 'writeFileSync').mockImplementation(() => undefined);
      const runner = fakeRunner({});
      makeService(runner).setBrightness(80);
      expect(writeSpy).not.toHaveBeenCalled();
    });
  });
});