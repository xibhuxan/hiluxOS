-- Runs only when the PostgreSQL data volume is initialized for the first time.
-- The application schema is managed by Prisma migrations (backend/prisma).
-- This file only enables extensions that the app may rely on.

CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";