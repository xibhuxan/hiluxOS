import { Injectable } from '@nestjs/common';
import { execFileSync } from 'node:child_process';

/**
 * Result of a command execution. `stdout` is the captured output (null when the
 * binary is missing or the command failed, so callers can degrade gracefully).
 */
export interface CommandResult {
  stdout: string | null;
  success: boolean;
}

/**
 * Thin, injectable wrapper around `node:child_process.execFileSync`.
 *
 * Centralising shell access here lets unit tests replace the runner with a mock
 * instead of spawning real `nmcli` / `bluetoothctl` processes, which would be
 * slow, flaky and platform-dependent.
 */
@Injectable()
export class CommandRunner {
  /** Run a command, returning stdout or null if it fails/unavailable. */
  run(bin: string, args: string[], timeoutMs = 2000): string | null {
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

  /**
   * Run a command, returning stdout. Throws on failure so callers can surface
   * a meaningful error. Pass `stdin` for interactive CLIs that read from stdin.
   */
  runOrThrow(bin: string, args: string[], timeoutMs = 2000, stdin?: string): string {
    return execFileSync(bin, args, {
      encoding: 'utf8',
      timeout: timeoutMs,
      stdio: ['pipe', 'pipe', 'pipe'],
      input: stdin,
    });
  }

  /**
   * Run a command with a binary (PCM) stdin payload, returning raw stdout bytes.
   * Used by the voice driver to stream captured audio to the ASR helper.
   */
  runOrThrowBuffer(bin: string, args: string[], timeoutMs = 2000, stdin?: Buffer): Buffer {
    return execFileSync(bin, args, {
      timeout: timeoutMs,
      stdio: ['pipe', 'pipe', 'pipe'],
      input: stdin,
      maxBuffer: 64 * 1024 * 1024,
    });
  }
}