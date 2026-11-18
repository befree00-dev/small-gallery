// Makes the "Secret Key" Supabase asks for under Authentication → Providers → Apple.
// Apple only accepts it for up to 6 months, so run this again before it expires.
//
//   node apple-secret.mjs <Team ID> <Key ID> <Services ID> <path to AuthKey_XXXX.p8>
//
// Runs on your computer only: the .p8 key is read locally and sent nowhere.
import { createPrivateKey, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const [teamId, keyId, clientId, keyPath] = process.argv.slice(2);
if (!teamId || !keyId || !clientId || !keyPath) {
  console.error('Usage: node apple-secret.mjs <Team ID> <Key ID> <Services ID> <AuthKey_XXXX.p8>');
  process.exit(1);
}

const b64url = (x) => Buffer.from(typeof x === 'string' ? x : JSON.stringify(x)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const days = 180;
const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
const claims = { iss: teamId, iat: now, exp: now + days * 86400, aud: 'https://appleid.apple.com', sub: clientId };
const input = `${b64url(header)}.${b64url(claims)}`;
// ES256 in JWTs uses the raw r||s signature, not DER.
const signature = sign('sha256', Buffer.from(input), {
  key: createPrivateKey(readFileSync(keyPath)),
  dsaEncoding: 'ieee-p1363',
});

console.log(`${input}.${signature.toString('base64url')}`);
console.error(`\nValid until ${new Date((now + days * 86400) * 1000).toISOString().slice(0, 10)}. Make a new one before then.`);
