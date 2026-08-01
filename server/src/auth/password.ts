import { randomBytes, scrypt as scryptCb, timingSafeEqual } from 'crypto';

function scrypt(password: string, salt: Buffer, keylen: number, options: { N: number; r: number; p: number }): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scryptCb(password, salt, keylen, { ...options, maxmem: MAX_MEM }, (err, key) => {
      if (err) reject(err);
      else resolve(key as Buffer);
    });
  });
}

// OWASP 建议 ≥ 2^17, r=8, p=1；node scrypt 默认 maxmem 32MB 需显式放大
const N = 131072;
const R = 8;
const P = 1;
const KEY_LEN = 64;
const SALT_LEN = 16;
const MAX_MEM = 256 * 1024 * 1024;
const PREFIX = 'scrypt';

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(SALT_LEN);
  const key = await scrypt(password, salt, KEY_LEN, { N, r: R, p: P });
  return [PREFIX, N, R, P, salt.toString('base64'), key.toString('base64')].join(':');
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split(':');
  if (parts.length !== 6 || parts[0] !== PREFIX) {
    throw new Error('malformed password hash');
  }
  const [prefix, nStr, rStr, pStr, saltB64, keyB64] = parts;
  const key = Buffer.from(keyB64, 'base64');
  const candidate = await scrypt(password, Buffer.from(saltB64, 'base64'), key.length, {
    N: Number(nStr),
    r: Number(rStr),
    p: Number(pStr),
  });
  return timingSafeEqual(key, candidate);
}
