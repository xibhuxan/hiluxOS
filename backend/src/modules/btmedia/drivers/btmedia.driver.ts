/**
 * Bluetooth Media HAL — driver interface.
 *
 * A2DP (audio streaming) + AVRCP (remote control / metadata) source: the car
 * acts as a Bluetooth *sink* for a paired phone. The UI talks only to this
 * abstraction; the substituted driver does the real work (BlueZ over
 * bluetoothctl / D-Bus) or simulates it (mock).
 *
 * Substitution chain (ARCHITECTURE.md): MockBtMediaDriver (default) →
 * BluezBtMediaDriver (parses `bluetoothctl`). Selection by env:
 * `BTMEDIA_DRIVER=mock|bluez`.
 *
 * Modelled state: whether the BT adapter/stack is available, whether a phone
 * is connected, the current track metadata + playback position, the AVRCP
 * playback status and a 0..1 volume. Actions are the classic AVRCP passthrough
 * commands (play/pause/next/previous) plus absolute volume.
 */

/** AVRCP playback status. */
export type BtMediaStatus = 'playing' | 'paused' | 'stopped';

/** Current track metadata (AVRCP). */
export interface BtTrack {
  title: string;
  artist: string;
  album: string;
  /** Total duration in seconds (0 when unknown). */
  durationSec: number;
  /** Current playback position in seconds. */
  positionSec: number;
}

/** The full Bluetooth-media state shown by the UI. */
export interface BtMediaState {
  /** Whether a BT adapter / stack is available (false → "Bluetooth no disponible"). */
  available: boolean;
  /** Whether a phone is currently connected (false → "Sin dispositivo"). */
  connected: boolean;
  /** Human-readable name of the connected device, when connected. */
  deviceName: string | null;
  /** Current track, when there is one. */
  track: BtTrack | null;
  /** AVRCP playback status. */
  status: BtMediaStatus;
  /** Absolute volume in [0, 1]. */
  volume: number;
}

/** Clamp a volume into [0, 1], rounded to 2 decimals. */
export function clampBtVolume(volume: number): number {
  const v = Math.min(1, Math.max(0, volume));
  return Math.round(v * 100) / 100;
}

/** The disconnected / empty baseline state. */
export function emptyBtMediaState(available: boolean): BtMediaState {
  return {
    available,
    connected: false,
    deviceName: null,
    track: null,
    status: 'stopped',
    volume: 0.7,
  };
}

/**
 * Abstract driver — the service/controller layers only ever see this.
 *
 * Implementations keep the *applied* state themselves (the mock in memory,
 * the BlueZ one reflected from bluetoothctl) so `getState()` is cheap and
 * never re-parses D-Bus on every poll.
 */
export abstract class BtMediaDriver {
  abstract readonly kind: string;

  /** The full current state (cheap, no re-parse). */
  abstract getState(): BtMediaState;

  /** AVRCP play. */
  abstract play(): BtMediaState;

  /** AVRCP pause. */
  abstract pause(): BtMediaState;

  /** AVRCP next track. */
  abstract next(): BtMediaState;

  /** AVRCP previous track (restarts the current track first, like most head units). */
  abstract previous(): BtMediaState;

  /** Set the absolute volume in [0, 1]. */
  abstract setVolume(volume: number): BtMediaState;
}
