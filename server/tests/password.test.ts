import { hashPassword, verifyPassword } from '../src/auth/password';

describe('password hashing (scrypt)', () => {
  it('hashes a password without storing it in plaintext', async () => {
    const hash = await hashPassword('correct-horse-123');
    expect(hash).not.toContain('correct-horse-123');
    expect(hash).toMatch(/^scrypt:/);
  });

  it('verifies the correct password and rejects wrong ones', async () => {
    const hash = await hashPassword('s3cret-pw');
    expect(await verifyPassword('s3cret-pw', hash)).toBe(true);
    expect(await verifyPassword('wrong-pw', hash)).toBe(false);
  });

  it('produces a unique salt per hash', async () => {
    const a = await hashPassword('same-password');
    const b = await hashPassword('same-password');
    expect(a).not.toBe(b);
  });

  it('rejects a malformed stored hash', async () => {
    await expect(verifyPassword('anything', 'not-a-valid-format')).rejects.toThrow();
  });
});
