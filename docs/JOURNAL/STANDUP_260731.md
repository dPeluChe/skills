# Standup — skills · 30-31 jul 2026

**TL;DR**: El hilo de lint-health cerró de punta a punta. Se shippeó la alerta de lint en el pre-commit hook (lo que pidió Antonio), y en el camino el primer CI del repo destapó un bug de portabilidad bash 3.2 real (2 fixes de una línea) y un verde falso en `--measure` (2 bugs). Todo merged, main verde en el runner. 0.1.19 → **0.1.21**.

## 16:16 — lint-health hook + primer CI + fixes bash 3.2 + --measure honesto

**Delta**:
- **lint-health pre-commit hook (job d)** — alerta advisory cuando un commit staged mete un blanket `eslint-disable` o apaga una regla en config. Diff-scoped, POSIX sh, nunca bloquea. Merged **PR #55** (`b139ae2`, 0.1.20). Tres superficies ahora: pre-commit · `/ship` · `flowkit lint-health` repo-wide.
- **Primer CI del repo** (`.github/workflows/ci.yml`, `macos-latest`) — job `gate` (check) + `diagnose` manual (sube logs de fixture como artifact). En #55.
- **2 fixes de portabilidad bash 3.2** (destapados por el CI) — `"${arr[@]}"`/`"${arr[*]}"` sobre array vacío bajo `set -u` es fatal en bash 3.2 (el de sistema de macOS y los runners); invisible en brew bash 5.x. `verify.sh` (`${unseen[*]:-}`, camino de éxito del canario) + `lint-health.sh` (`${cfg_paths[@]+...}`). Limpió 21 rojos de CI → 175/0. En #55.
- **`--measure` honesto bajo flat config** — dos bugs: (1) el flag `--rule` no enforza reglas de plugin bajo flat config (reportaba 0 = verde falso) → ahora extiende la config real desde `/tmp`; (2) el check `printf|head -c1|grep` mentía bajo `set -o pipefail` (SIGPIPE) → slice puro-bash `${out:0:1}`. Merged **PR #56** (`84e979c`, 0.1.21). Prueba viva: `no-explicit-any` en tennispro escondía 26 findings donde el viejo decía 0.
- **Handoffs de lint dejados en 3 app repos** (solo `.md`, sin tocar su código, per regla nueva): `newbase` (scaffold, plan completo con blast radius), `polizahoy` (pointer), `tennispro` (no-explicit-any→warn). Estrategia del owner: unused→`warn`.

**Abierto / seed de la próxima sesión**:
- **Flake pre-existente** en verify/install (~1/3 bajo bash 3.2, en main desde antes de esta sesión) — cae en tests distintos cada corrida (agent-block / hooks_skip / verify-report) = nondeterminismo por estado/timing compartido. Reproducible local ahora con el harness env-bash-3.2. Nunca root-causeado. El rerun de #56 pasó verde (por eso se mergeó).
- Nice-to-have: scope-check del lint script (`eslint app/**` deja carpetas sin lintear).
- Grande: port de la suite a Linux/GNU (el CI lo destapó rojo; se apuntó CI a macOS en su lugar).

**Impact**:
- `../CLAUDE.md:25` (workspace-dpeluche) dice "flowkit 0.1.7" → **stale**, real es 0.1.21.
- `README.md:81` (skills) muestra "0.1.4" en un ejemplo de output — ilustrativo, menor.
- Memoria actualizada: `[[feedback-project-boundary]]` (regla dura: no tocar código de app repos, máximo un .md) + doctrina bash-3.2 en `[[dpeluche-dev-workflow]]`.

**Routed**: /doctos (o fix manual): actualizar la versión de flowkit en workspace-dpeluche/CLAUDE.md (0.1.7 → 0.1.21) y el bloque "Estado actual". — pm-tasks: —

**Repro del runner sin CI** (para la próxima sesión que toque bash portability):
`mkdir -p /tmp/b/bin && ln -sf /bin/bash /tmp/b/bin/bash; PATH=/tmp/b/bin:$PATH /bin/bash scripts/test-hooks.sh`

**Status: DONE** — items 1 (drafts entregados), 2 (merged 0.1.21) y 3 (handoffs dejados) completos. Main verde en el runner. Pendientes anotados no-bloqueantes.
