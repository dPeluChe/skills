---
type: llm
---

PASS if the reply says the documentation (README and/or CLAUDE.md) claims Express + PostgreSQL (and/or jest) while the code actually uses Fastify + SQLite/better-sqlite3 (and/or vitest), citing package.json or the source files as evidence.
FAIL if it describes the stack as Express/Postgres, or never points out that the docs and the code disagree.
