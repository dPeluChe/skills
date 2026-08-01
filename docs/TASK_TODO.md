# skills — Task TODO

> Roadmap **público** de flowkit y la mecánica de las agent skills (tooling
> verificable). El material **editorial** (writer, social-posts, la voz de
> Antonio, estrategia de anuncios) vive privado en `dpeluche.dev/docs/TASK_TODO.md`.
> Lo terminado va al journal (`docs/JOURNAL/`), no aquí.

## flowkit — mejoras de campo

- [ ] **`lint-health --measure` — simular el gate REAL del repo**: además del conteo de hallazgos, leer el comando de gate de `package.json` (ej. `lint:strict --max-warnings 0`) y reportar si esas N violaciones **romperían el gate**, no solo cuántas hay. Origen: field-test dev tennispro — el `--max-warnings 0` solo apareció al EJECUTAR el cambio, no al leer la config (`warn` ahí == `error`); un `--measure` que simule el efecto lo cazaría solo. Prioridad: valioso pero puntual (solo al decidir encender una regla en repo con gate estricto) — esperar más field-tests. `added: 2026-07-31`

## Deuda técnica (no bloqueante)

- [ ] **Flake en verify/install bajo bash 3.2**: ~1/3 de rate, cae en tests distintos cada corrida (agent-block / hooks_skip / verify-report) = nondeterminismo por estado/timing compartido. En `main` desde antes; nunca root-causeado. Repro fiel del runner sin CI: `mkdir -p /tmp/b/bin && ln -sf /bin/bash /tmp/b/bin/bash; PATH=/tmp/b/bin:$PATH /bin/bash scripts/test-hooks.sh`. `added: 2026-07-31`
- [ ] **Scope-check del script de lint**: detectar un `eslint app/**` que deja carpetas (`convex/`, `scripts/`) sin lintear — señal para `flowkit lint-health`. Nice-to-have. `added: 2026-07-31`
- [ ] **Port de la suite a Linux/GNU**: `install`/`verify` fallan en Linux (el CI apunta a macOS por eso). Solo vale si algún consumer corre en Linux. `added: 2026-07-31`
