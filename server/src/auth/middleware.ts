import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthUser {
  sub: string;
  bookId?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export function authMiddleware(secret: string) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    try {
      const payload = jwt.verify(header.slice(7), secret) as AuthUser;
      req.user = payload;
      next();
    } catch {
      res.status(401).json({ error: 'unauthorized' });
    }
  };
}
