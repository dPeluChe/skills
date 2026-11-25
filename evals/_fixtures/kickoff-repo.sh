#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks are literal markdown in the fixture files
# TaskNote: docs claim Express + Postgres + jest; the code moved to Fastify + SQLite + vitest.
set -euo pipefail
g() { git -c user.name=Dev -c user.email=dev@example.test "$@"; }
commit() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" g commit -qm "$2"; }
g init -q -b main .
mkdir -p src/auth src/export docs/JOURNAL
cat > README.md <<'MD'
# TaskNote

REST API for personal task notes, built with **Express** and **PostgreSQL** (`pg`).

    npm install && npm start   # needs DATABASE_URL
    npm test                   # jest
MD
cat > CLAUDE.md <<'MD'
# CLAUDE.md
Stack: Express 4 + PostgreSQL via `pg`. Tests with jest. Entry point: `src/server.js`.
MD
cat > package.json <<'MD'
{ "name": "tasknote", "version": "0.3.0", "type": "module",
  "scripts": { "start": "node src/server.js", "test": "vitest run" },
  "dependencies": { "fastify": "^5.1.0", "better-sqlite3": "^11.5.0" },
  "devDependencies": { "vitest": "^2.1.0" } }
MD
cat > src/server.js <<'MD'
import Fastify from 'fastify';
import { db } from './db.js';
const app = Fastify();
app.get('/notes', () => db.prepare('SELECT * FROM notes').all());
app.listen({ port: 3000 });
MD
cat > src/db.js <<'MD'
import Database from 'better-sqlite3';
export const db = new Database('tasknote.db');
db.exec('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY, body TEXT)');
MD
cat > docs/TASK_TODO.md <<'MD'
# TASK_TODO

## Noviembre 2026
- [ ] Implementar login (POST /login con sesión)
- [ ] Exportar notas a CSV
- [ ] Paginación en GET /notes
MD
cat > docs/JOURNAL/2026-11-10_STANDUP.md <<'MD'
# Standup 10 nov 2026
Hecho: migración a Fastify + SQLite.
Quedó pendiente: login y export a CSV. Siguiente: login.
MD
g add -A; commit 2026-10-01T10:00:00 "feat: notes API (express + pg)"
commit_all() { g add -A; commit "$1" "$2"; }
echo '// migrated' >> src/server.js; commit_all 2026-11-08T10:00:00 "refactor: migrate express/pg to fastify + better-sqlite3"
cat > src/auth/login.js <<'MD'
export async function login(req, reply) {
  const { user, pass } = req.body;
  if (!user || !pass) return reply.code(400).send({ error: 'missing credentials' });
  return { token: `session-${user}` };
}
MD
commit_all 2026-11-12T18:00:00 "feat(auth): POST /login endpoint"
cat > src/export/csv.js <<'MD'
// WIP: export notes to CSV
export function toCsv(rows) {
  return rows.map(r => `${r.id},${JSON.stringify(r.body)}`).join('\n');
}
MD
