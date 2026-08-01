# skills — Task TODO

> Roadmap **público** de flowkit y la mecánica de las agent skills (tooling
> verificable). El material **editorial** (writer, social-posts, la voz de
> Antonio, estrategia de anuncios) vive privado en `dpeluche.dev/docs/TASK_TODO.md`.
> Lo terminado va al journal (`docs/JOURNAL/`), no aquí.

## flowkit — mejoras de campo

- [ ] **`lint-health --measure` — simular el gate REAL del repo**: además del conteo de hallazgos, leer el comando de gate de `package.json` (ej. `lint:strict --max-warnings 0`) y reportar si esas N violaciones **romperían el gate**, no solo cuántas hay. Origen: field-test dev tennispro — el `--max-warnings 0` solo apareció al EJECUTAR el cambio, no al leer la config (`warn` ahí == `error`); un `--measure` que simule el efecto lo cazaría solo. Prioridad: valioso pero puntual (solo al decidir encender una regla en repo con gate estricto) — esperar más field-tests. `added: 2026-07-31`

- [ ] **`lint-health --canary` — probar que el linter ALCANZA los archivos, no solo que las reglas están on**: el modelo es el canario de gitleaks (inyectar una violación, verificar que el hook la bloquea). lint-health hoy pregunta "¿apagaron una regla?" pero no "¿el linter parsea/cubre los archivos que dice cubrir?". Bug de campo (dev blueprint-landings): un `languageOptions` reemplazó el parser → 36 archivos `.astro` sin revisar → `npm run lint` verde. **4 trampas de diseño (del dev que lo pisó):** (1) correr el **comando propio del repo** (`npm run lint`), no un eslint sintético — el bug vivía en la resolución de parser/archivos, cualquier invocación que no pase por el gate real no lo reproduce; (2) una violación por **extensión realmente presente**, plantada **junto a un archivo ya cubierto** de esa extensión (si cae en ruta ignorada → falso positivo); (3) elegir la regla desde el **config ya parseado** (lint-health ya lo lee), no una fija — evita el falso positivo del repo que apagó `no-unused-vars`; (4) **distinguir "lo marcó por lo que planté" de "lo marcó por parse error"** — son dos fallas distintas, el parse error es un hallazgo por derecho propio, NO evidencia de que el canario funcionó (si solo pregunta "¿hubo salida?", el modo ruidoso lo hace pasar con el gate roto). Se relaciona con el `--measure` gate-sim (ambos: correr el gate real del repo). `added: 2026-08-01`

## Deuda técnica (no bloqueante)

- [ ] **Flake en verify/install bajo bash 3.2**: ~1/3 de rate, cae en tests distintos cada corrida (agent-block / hooks_skip / verify-report) = nondeterminismo por estado/timing compartido. En `main` desde antes; nunca root-causeado. Repro fiel del runner sin CI: `mkdir -p /tmp/b/bin && ln -sf /bin/bash /tmp/b/bin/bash; PATH=/tmp/b/bin:$PATH /bin/bash scripts/test-hooks.sh`. `added: 2026-07-31`
- [ ] **Scope-check del script de lint**: detectar un `eslint app/**` que deja carpetas (`convex/`, `scripts/`) sin lintear — señal para `flowkit lint-health`. Nice-to-have. `added: 2026-07-31`
- [ ] **Port de la suite a Linux/GNU**: `install`/`verify` fallan en Linux (el CI apunta a macOS por eso). Solo vale si algún consumer corre en Linux. `added: 2026-07-31`
