#!/usr/bin/env node
/**
 * Generate an Ed25519 key pair for signing OTA update bundles.
 *
 * Outputs:
 *   - Public key (base64 DER SPKI)  → set as UPDATE_PUBLIC_KEY in the backend env
 *   - Private key (base64 DER PKCS8) → keep secret, used by the release tooling
 *
 * Usage: node scripts/generate-update-keys.js
 */
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');

const pubB64 = publicKey.export({ format: 'der', type: 'spki' }).toString('base64');
const privB64 = privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64');

console.log('=== Ed25519 Key Pair for OTA Updates ===\n');
console.log('Public key (set as UPDATE_PUBLIC_KEY in backend .env):');
console.log(pubB64);
console.log('\nPrivate key (KEEP SECRET — used to sign releases):');
console.log(privB64);

// Optionally save to files
const outDir = path.resolve(__dirname);
const pubPath = path.join(outDir, 'update-pub.key');
const privPath = path.join(outDir, 'update-priv.key');

fs.writeFileSync(pubPath, pubB64 + '\n', { mode: 0o644 });
fs.writeFileSync(privPath, privB64 + '\n', { mode: 0o600 });

console.log(`\nSaved to:\n  ${pubPath}\n  ${privPath}`);
console.log('\n⚠  Add update-priv.key to .gitignore! Never commit the private key.');