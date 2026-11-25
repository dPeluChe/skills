#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks are literal markdown in the fixture files
# A repo whose root collects stray docs, a task list and an obsolete plan.
set -euo pipefail
git -c init.defaultBranch=main init -q .
mkdir -p docs src
echo '# Inventa: inventory API. See docs/ for guides.' > README.md
echo '# CLAUDE.md'$'\n''Node 22 + Hono. Run `npm run dev`.' > CLAUDE.md
printf '# notes\n- la api de stock tarda 2s en /items\n- revisar cache\n' > notes.md
printf '# Setup guide\n1. Install Node 22\n2. cp .env.example .env\n3. npm run dev\n' > setup-guide.md
printf '# Architecture v2\nHono app, SQLite, a worker for stock sync.\n' > architecture-v2.md
printf '# Plan Q1 2024 (reemplazado por el plan de 2025)\nMigrar a Hono. Hecho en 2024.\n' > old-plan-2024.md
printf '# TODO\n- [ ] Cache de /items\n- [x] Migrar a Hono\n' > TODO.md
printf '# api\nGET /items, POST /items\n' > docs/api.md
echo 'export default {}' > src/index.js
echo '{ "name": "inventa", "private": true }' > package.json
git add -A && git -c user.name=Dev -c user.email=dev@example.test commit -qm "docs: initial"
