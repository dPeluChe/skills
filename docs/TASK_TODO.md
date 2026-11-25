# skills: Task TODO

> Roadmap **público** de flowkit y la mecánica de las agent skills (tooling
> verificable). El material **editorial** (writer, social-posts, la voz de
> Antonio, estrategia de anuncios) vive privado en `dpeluche.dev/docs/TASK_TODO.md`.
> Lo terminado va al journal (`docs/JOURNAL/`), no aquí.

## flowkit: mejoras de campo

- [ ] **`lint-health --measure`: simular el gate REAL del repo**: además del conteo de hallazgos, leer el comando de gate de `package.json` (ej. `lint:strict --max-warnings 0`) y reportar si esas N violaciones **romperían el gate**, no solo cuántas hay. Origen: field-test dev tennispro: el `--max-warnings 0` solo apareció al EJECUTAR el cambio, no al leer la config (`warn` ahí == `error`); un `--measure` que simule el efecto lo cazaría solo. Prioridad: valioso pero puntual (solo al decidir encender una regla en repo con gate estricto), esperar más field-tests. `added: 2026-07-31`

## preship y el /ship nativo

- [ ] **Migrar repos ya conectados a `## preship config`**: el encabezado viejo se sigue leyendo, así que no urge; `flowkit hooks` podría ofrecer renombrarlo. `added: 2026-11-24`

## Research en pausa

- [ ] **Decidir la propuesta de `docs/RESEARCH/SKILLS_ECOSYSTEM_2611.md`** (evals, loop estilo `/correct`, anti-slop de UI, auditoría de seguridad, guard freeze). `added: 2026-11-24`

## Deuda técnica (no bloqueante)

- [ ] **Scope-check del script de lint**: detectar un `eslint app/**` que deja carpetas (`convex/`, `scripts/`) sin lintear, señal para `flowkit lint-health`. Nice-to-have. `added: 2026-07-31`
- [ ] **Suite en ~4.5 min**: `FLOWKIT_TIMINGS=1 bash scripts/test-hooks.sh` da 71s en 40-install-repo, 71s en 90-gitleaks-scope y 49s en 70-field-feedback. El costo es el canario de cada wiring (7 corridas de lefthook, ~4s). Opciones: módulos en paralelo con `$TMP` por módulo, o un canario opt-out solo en fixtures que no lo prueban. `added: 2026-11-24`
- [ ] **Port de la suite a Linux/GNU**: `install`/`verify` fallan en Linux (el CI apunta a macOS por eso). Solo vale si algún consumer corre en Linux. `added: 2026-07-31`
