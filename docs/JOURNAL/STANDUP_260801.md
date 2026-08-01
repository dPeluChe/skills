# Standup — skills · 31 jul – 1 ago 2026 (ciclo de field-tests)

**TL;DR**: Tres field-tests reales (tennispro, blueprint-landings, un review de regresión) se volvieron features/fixes/guías de flowkit. **0.1.21 → 0.1.32**, 8 PRs, cada cambio con test y verde en bash 5.x + 3.2. El hallazgo mayor no fue técnico: el loop field-test → implementación atrapa dos clases de bug — pero solo con **sesiones separadas**, y su costo (relay manual) cae en Antonio.

## Shipped (por field-test)

**tennispro (dev que auditó lint-health):**
- **`--measure` honesto** (`84e979c`, 0.1.21): bajo flat config el `--rule` no medía reglas de plugin (verde falso) → ahora extiende la config real desde `/tmp`; + fix del `printf|head|grep` que mentía bajo `pipefail` (SIGPIPE).
- **lint-health scope-aware** (`1a78b20`, 0.1.22, #58): usaba text-read y marcaba un override `files:` scopeado como "off repo-wide". Ahora `eslint --print-config` es la fuente autoritativa. Su hallazgo destapó que **mi handoff de newbase también estaba inflado** (6 off → 4 reales).
- **typecheck framework-aware** (`bcd4faf`, 0.1.27, #64): el ship config sugería `tsc --noEmit` en repos Astro — el falso verde exacto que /ship advierte. Ahora `astro check`/`vue-tsc`/`svelte-check` por deps.

**blueprint-landings (dev nuevo, repo Astro):**
- **`lint-health --canary`** (`c189f48`, 0.1.26, #63): prueba que el linter ALCANZA cada extensión (caught/BLIND/parse-error) corriendo el gate real del repo. Sus 4 trampas de diseño horneadas.
- **Corrección del canario** (`650141f`, 0.1.29, #66): el dev verificó su propia anécdota y era falsa — su lint era honesto; el fallo real fue el modo ruidoso (parse errors por un bump de deps). Corregí el encuadre en código + README. La feature se sostiene; la trampa #4 (parse error = hallazgo propio) quedó como la MVP.
- **Nudge de lockfile** (`452d7d6`, 0.1.30, #67): un bump de deps corre la cobertura de lint con un diff que solo toca el lockfile — invisible a los chequeos de código. El pre-commit ahora avisa de correr `--canary` cuando el lockfile cambia.
- **`about` read-only** (`a71bfe2`, 0.1.28, #65): `flowkit hooks` escribía y era la forma de leer el consejo; `about` ahora da "Suggested next" sin escribir.
- **Batch A UX** (`44cc22d`, 0.1.25, #62): repo fresco → canario DEFERRED (no FAIL); problema repetido junto al resumen; guía de gitleaks solo en la 1ª wiring.

**Review de regresión de hooks:**
- **verify GRITA en hooks desplazados** (`6f8d597`, 0.1.31, #68): wirear un repo con su `.git/hooks/` propio dejaba el hook muerto (lefthook lo respalda a `.old` y lo reemplaza) y `--verify` decía verde. Ahora FAIL + aviso. **NO auto-encadena**: lo intenté y el `exit 0` del old hook enmascaraba el bloqueo de secretos (canario en UNSEEN). Gritar + guiar la migración es la respuesta verificada-segura.
- **git-guard nombra la salida legítima** (`b5492ba`, 0.1.32, #69): bloquear `--no-verify` sin decir la alternativa deja al agente sin vía en mantenimiento legítimo. El mensaje ahora apunta al patrón (el hook DECIDE vía una condición que lee, no bypass) — la doctrina de `hooks_skip` generalizada.

## El hallazgo que vale (metodológico)

El loop atrapó **dos clases de bug**: el que revisa desde el repo real ve lo que no se lee en código (cobertura, lockfile, hook desplazado, salida del guard); el que implementa ve lo que no se ve sin ejecutar (canario en UNSEEN, `--rule` sin plugins, `tsc` vs `.astro`, la anécdota falsa). **Seis correcciones, tres por lado.** La condición no-obvia: **sesiones separadas** — un mismo agente verifica sus propias suposiciones y pierde las dos clases a la vez. Nació de la regla de propiedad ([[feedback-project-boundary]]) pero es también la epistemología del loop.

**La segunda mitad (no romantizar): el loop lo subsidia Antonio.** La separación obliga a un humano a cargar el relay — ~6 bloques pegados entre 3 conversaciones esta sesión. Es la **fricción #1** de la auditoría de conversaciones. Bajar ese costo sin colapsar la separación queda **abierto, no resuelto.**

## Impact
- Docs de flowkit (código + README) al día con cada PR. `../CLAUDE.md` del workspace no hardcodea versión (bien).
- Memoria: doctrina del loop-de-sesiones-separadas + su costo añadida a [[dpeluche-dev-workflow]].
- `docs/TASK_TODO.md` (skills, público) tiene el backlog vivo: `--measure` gate-sim (pendiente, del dev de tennispro) + deuda técnica.

**Routed**: — (sin docs stale ni tareas completadas que archivar detectadas en el diff).

**Pendiente abierto de más peso**: bajar el costo del relay manual entre agentes sin colapsar la separación de sesiones (fricción #1). Candidato viejo del [[project_conversation_audit]].

**Status: DONE** — flowkit 0.1.19→0.1.32, 8 PRs mergeados, main verde en el runner, cola de field-tests en cero.
