import { Injectable, Logger } from '@nestjs/common';
import crypto from 'node:crypto';
import fs from 'node:fs';

/**
 * Verifies Ed25519 signatures on update bundles.
 * Bundle format: a tar.gz whose bytes are signed; the signature is a base64
 * Ed25519 signature provided in the GitHub release assets as `*.sig`.
 */
@Injectable()
export class SignatureService {
  private readonly logger = new Logger(SignatureService.name);

  /**
   * Verify a bundle file against a signature using the public key.
   * @param filePath  Absolute path to the downloaded bundle.
   * @param signatureBase64  Base64-encoded Ed25519 signature.
   * @param publicKeyBase64  Base64-encoded Ed25519 public key (32 bytes).
   * @returns true if the signature is valid.
   */
  verify(filePath: string, signatureBase64: string, publicKeyBase64: string): boolean {
    try {
      const sig = Buffer.from(signatureBase64, 'base64');
      const keyBytes = Buffer.from(publicKeyBase64, 'base64');

      // Node's crypto.verify expects a KeyObject for Ed25519.
      const key = crypto.createPublicKey({
        key: keyBytes,
        format: 'der',
        type: 'spki',
      });

      const data = fs.readFileSync(filePath);
      return crypto.verify(null, data, key, sig);
    } catch (err) {
      this.logger.error(`Signature verification failed: ${(err as Error).message}`);
      return false;
    }
  }

  /**
   * Generate a key pair for signing bundles (used by the release tooling,
   * not by the running backend).
   */
  static generateKeyPair(): { publicKey: string; privateKey: string } {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
    return {
      publicKey: publicKey.export({ format: 'der', type: 'spki' }).toString('base64'),
      privateKey: privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64'),
    };
  }
}