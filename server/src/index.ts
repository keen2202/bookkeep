import { Pool } from 'pg';
import { createApp } from './app';

const port = Number(process.env.PORT ?? 3000);
const pool = new Pool({
  connectionString: process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep',
});

if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  console.error('JWT_SECRET is required in production');
  process.exit(1);
}
const app = createApp({ pool, jwtSecret: process.env.JWT_SECRET ?? 'dev-secret' });

app.listen(port, () => {
  console.log(`bookkeep server listening on :${port}`);
});
