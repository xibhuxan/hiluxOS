#!/usr/bin/env node
/**
 * Package a hiluxOS release bundle and sign it.
 *
 * Produces:
 *   - hiluxos-X.Y.Z.tar.gz     (the bundle)
 *   - hiluxos-X.Y.Z.tar.gz.sig (the Ed25519 signature)
 *
 * Usage:
 *   node scripts/package-release.js <version> [--priv-key <path>]
 *
 * The private key file should contain a base64 DER PKCS8 Ed25519 key.
 * If --priv-key is omitted, looks for scripts/update-priv.key.
 */
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

const args = process.argv.slice(2);
const versionArg = args.find((a) => !a.startsWith('--'));
if (!versionArg) {
  console.error('Usage: node scripts/package-release.js <version> [--priv-key <path>]');
  process.exit(1);
}
const version = versionArg.replace(/^v/, '');

const privKeyIdx = args.indexOf('--priv-key');
const privKeyPath = privKeyIdx !== -1 && args[privKeyIdx + 1]
  ? args[privKeyIdx + 1]
  : path.join(__dirname, 'update-priv.key');

if (!fs.existsSync(privKeyPath)) {
  console.error(`Private key not found: ${privKeyPath}`);
  console.error('Generate it with: node scripts/generate-update-keys.js');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'dist');
fs.mkdirSync(outDir, { recursive: true });

const bundleName = `hiluxos-${version}.tar.gz`;
const bundlePath = path.join(outDir, bundleName);
const sigPath = bundlePath + '.sig';

// Create the tarball from the repo root, excluding dev/build artifacts.
// The tarball has a top-level directory "hiluxos-{version}/" so the
// backend can extract with strip: 1.
const topDir = `hiluxos-${version}`;
const excludes = [
  '--exclude=node_modules',
  '--exclude=.git',
  '--exclude=dist',
  '--exclude=.env',
  '--exclude=venv',
  '--exclude=*.log',
  '--exclude=app/build',
  '--exclude=app/.dart_tool',
];

console.log(`Packaging ${bundleName}...`);
execSync(
  `tar czf "${bundlePath}" ${excludes.join(' ')} --transform="s,^,${topDir}/," .`,
  { cwd: root, stdio: 'inherit' },
);

console.log(`Signing with ${privKeyPath}...`);
const privKeyDer = Buffer.from(fs.readFileSync(privKeyPath, 'utf8').trim(), 'base64');
const privateKey = crypto.createPrivateKey({ key: privKeyDer, format: 'der', type: 'pkcs8' });
const data = fs.readFileSync(bundlePath);
const sig = crypto.sign(null, data, privateKey);
fs.writeFileSync(sigPath, sig.toString('base64'));

console.log(`\nDone! Upload these to GitHub release v${version}:`);
console.log(`  ${bundlePath}`);
console.log(`  ${sigPath}`);