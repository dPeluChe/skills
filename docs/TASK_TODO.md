# skills: Task TODO

> Roadmap **público** de flowkit y la mecánica de las agent skills (tooling
> verificable). El material **editorial** (writer, social-posts, la voz de
> Antonio, estrategia de anuncios) vive privado en `dpeluche.dev/docs/TASK_TODO.md`.
> Lo terminado va al journal (`docs/JOURNAL/`), no aquí.

## flowkit: mejoras de campo

- [ ] **lefthook ≥ 2.0.5 en cada máquina (fuera de este repo)**: desde 0.1.38 la config central exige `min_version: 2.0.5`; una máquina con lefthook viejo ve fallar los hooks hasta `brew upgrade lefthook`. Se revisa por máquina (jakku, lego2max, colaboradores), no aquí. `added: 2026-11-25`
- [ ] **`lint-health --measure`: simular el gate REAL del repo**: además del conteo de hallazgos, leer el comando de gate de `package.json` (ej. `lint:strict --max-warnings 0`) y reportar si esas N violaciones **romperían el gate**, no solo cuántas hay. Origen: field-test dev tennispro: el `--max-warnings 0` solo apareció al EJECUTAR el cambio, no al leer la config (`warn` ahí == `error`); un `--measure` que simule el efecto lo cazaría solo. Prioridad: valioso pero puntual (solo al decidir encender una regla en repo con gate estricto), esperar más field-tests. `added: 2026-07-31`

## preship y el /ship nativo

- [ ] **Migrar repos ya conectados a `## preship config`, de paso**: el encabezado viejo se sigue leyendo, así que no urge ni amerita una ronda por los ~55 repos. Que `flowkit hooks` / `flowkit upgrade` lo renombre cuando ya estén en ese repo por otra razón. `added: 2026-11-24`

## Evals: pendientes para otro día

- [ ] **Benchmark firme por modelo**: la suite completa a `--runs 3` por brazo en Haiku, Sonnet y Opus (unos $15 a $20), publicado en el journal como la referencia. Hoy Haiku tiene 2 corridas y Opus 1 sobre 8 casos (`docs/JOURNAL/STANDUP_261125.md`). `added: 2026-11-25`
- [ ] **Set de triggers por skill**: 8 a 10 frases que deben activarla y otras tantas que casi la activan, al estilo skill-creator. Origen: en Haiku, pm-tasks no se activó con "que hay pendiente en este proyecto?" en 1 de 2 corridas. `added: 2026-11-25`
- [ ] **doctos y pm-tasks bajo 5000 tokens**: quedan cerca de 5500 tras el split a references; el siguiente corte es la prosa de AUDIT. `added: 2026-11-25`

## Research en pausa

- [ ] **Decidir la propuesta de `docs/RESEARCH/SKILLS_ECOSYSTEM_2611.md`** (evals, loop estilo `/correct`, anti-slop de UI, auditoría de seguridad, guard freeze). `added: 2026-11-24`

## Deuda técnica (no bloqueante)

- [ ] **Scope-check del script de lint**: detectar un `eslint app/**` que deja carpetas (`convex/`, `scripts/`) sin lintear, señal para `flowkit lint-health`. Nice-to-have. `added: 2026-07-31`
- [ ] **Suite en ~3 min**: `FLOWKIT_TIMINGS=1 bash scripts/test-hooks.sh` da 57s en 40-install-repo, 45s en 90-gitleaks-scope y 43s en 70-field-feedback. El costo es el canario de cada wiring (7 corridas del hook; el lote se descartó porque un conteo de leaks puede tapar una regla perdida). Siguiente opción: módulos en paralelo con `$TMP` por módulo. `added: 2026-11-24`
- [ ] **Port de la suite a Linux/GNU**: `install`/`verify` fallan en Linux (el CI apunta a macOS por eso). Solo vale si algún consumer corre en Linux. `added: 2026-07-31`
