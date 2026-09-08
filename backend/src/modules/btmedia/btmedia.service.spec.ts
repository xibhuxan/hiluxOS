import { BtMediaService } from './btmedia.service';
import { MockBtMediaDriver } from './drivers/mock-btmedia.driver';
import { BluezBtMediaDriver } from './drivers/bluez-btmedia.driver';
import { CommandRunner } from '../system/command-runner';

/** Build a service over a mock driver with a controllable fake clock. */
function makeMock() {
  let now = 1_000_000; // ms — arbitrary fixed start
  const driver = new MockBtMediaDriver(() => now);
  const svc = new BtMediaService(driver);
  return { svc, driver, advance: (ms: number) => (now += ms) };
}

describe('BtMediaService (mock driver)', () => {
  describe('state', () => {
    it('starts available, connected, paused on the first track', () => {
      const { svc } = makeMock();
      const s = svc.getState();
      expect(s.available).toBe(true);
      expect(s.connected).toBe(true);
      expect(s.deviceName).toBeTruthy();
      expect(s.status).toBe('paused');
      expect(s.track).not.toBeNull();
      expect(s.track!.title).toBe('Highway to Hell');
      expect(s.track!.positionSec).toBe(0);
      expect(s.volume).toBeCloseTo(0.7);
    });
  });

  describe('transport', () => {
    it('play starts playback and the position advances with the clock', () => {
      const { svc, advance } = makeMock();
      svc.play();
      advance(5000); // 5 s
      const s = svc.getState();
      expect(s.status).toBe('playing');
      expect(s.track!.positionSec).toBe(5);
    });

    it('pause freezes the position', () => {
      const { svc, advance } = makeMock();
      svc.play();
      advance(3000);
      svc.pause();
      advance(10000);
      const s = svc.getState();
      expect(s.status).toBe('paused');
      expect(s.track!.positionSec).toBe(3);
    });

    it('next moves to the next track and resets the position', () => {
      const { svc, advance } = makeMock();
      svc.play();
      advance(5000);
      const s = svc.next();
      expect(s.track!.title).toBe('Radar Love');
      expect(s.track!.positionSec).toBe(0);
    });

    it('previous restarts the current track when a few seconds in', () => {
      const { svc, advance } = makeMock();
      svc.play();
      advance(8000); // 8 s into the track (> 3 s threshold)
      const s = svc.previous();
      expect(s.track!.title).toBe('Highway to Hell'); // same track
      expect(s.track!.positionSec).toBe(0);
    });

    it('previous goes to the previous track when near the start', () => {
      const { svc, advance } = makeMock();
      svc.play();
      advance(1000); // 1 s in (< 3 s threshold)
      const s = svc.previous();
      // Wraps around to the last track of the playlist.
      expect(s.track!.title).toBe('Drive');
      expect(s.track!.positionSec).toBe(0);
    });

    it('auto-advances to the next track when the current one finishes', () => {
      const { svc, advance } = makeMock();
      svc.play();
      advance(210_000); // 210 s > 208 s of Highway to Hell
      const s = svc.getState();
      expect(s.track!.title).toBe('Radar Love');
      expect(s.track!.positionSec).toBe(2);
      expect(s.status).toBe('playing');
    });
  });

  describe('volume', () => {
    it('sets the volume and clamps into [0, 1]', () => {
      const { svc } = makeMock();
      expect(svc.setVolume(0.4).volume).toBe(0.4);
      expect(svc.setVolume(1.7).volume).toBe(1);
      expect(svc.setVolume(-0.2).volume).toBe(0);
    });
  });
});

describe('BluezBtMediaDriver', () => {
  function makeBluez(handler: (bin: string, args: string[]) => string | null) {
    const cmd = { run: jest.fn(handler), runOrThrow: jest.fn() } as unknown as CommandRunner;
    return new BluezBtMediaDriver(cmd);
  }

  it('degrades to available:false when bluetoothctl is missing', () => {
    const d = makeBluez(() => null);
    const s = d.getState();
    expect(s.available).toBe(false);
    expect(s.connected).toBe(false);
    expect(s.deviceName).toBeNull();
    expect(s.track).toBeNull();
  });

  it('degrades to available:false when the adapter is powered off', () => {
    const d = makeBluez((_bin, args) =>
      args[0] === 'show' ? 'Powered: no' : null,
    );
    expect(d.getState().available).toBe(false);
  });

  it('reports connected:false when no device is connected', () => {
    const d = makeBluez((_bin, args) => {
      if (args[0] === 'show') return 'Powered: yes';
      if (args[0] === 'devices') return ''; // no connected devices
      return null;
    });
    const s = d.getState();
    expect(s.available).toBe(true);
    expect(s.connected).toBe(false);
    expect(s.track).toBeNull();
  });

  it('parses device + track metadata when a phone is connected', () => {
    const d = makeBluez((_bin, args) => {
      if (args[0] === 'show') return 'Powered: yes';
      if (args[0] === 'devices') return 'Device AA:BB:CC:DD:EE:FF Pixel 8 Pro';
      if (args[0] === 'player.show')
        return [
          'Status: playing',
          'Title: Radar Love',
          'Artist: Golden Earring',
          'Album: Moontan',
          'Duration: 382000',
          'Position: 120000',
        ].join('\n');
      return null;
    });
    const s = d.getState();
    expect(s.available).toBe(true);
    expect(s.connected).toBe(true);
    expect(s.deviceName).toBe('Pixel 8 Pro');
    expect(s.status).toBe('playing');
    expect(s.track).not.toBeNull();
    expect(s.track!.title).toBe('Radar Love');
    expect(s.track!.artist).toBe('Golden Earring');
    expect(s.track!.durationSec).toBe(382);
    expect(s.track!.positionSec).toBe(120);
  });

  it('keeps track null when player.show has no metadata (older BlueZ)', () => {
    const d = makeBluez((_bin, args) => {
      if (args[0] === 'show') return 'Powered: yes';
      if (args[0] === 'devices') return 'Device AA:BB:CC:DD:EE:FF Pixel 8 Pro';
      return null; // player.show empty / unsupported
    });
    const s = d.getState();
    expect(s.connected).toBe(true);
    expect(s.track).toBeNull();
    expect(s.status).toBe('stopped');
  });
});
