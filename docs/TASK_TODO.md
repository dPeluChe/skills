# skills: Task TODO

> Roadmap **público** de flowkit y la mecánica de las agent skills (tooling
> verificable). El material **editorial** (writer, social-posts, la voz de
> Antonio, estrategia de anuncios) vive privado en `dpeluche.dev/docs/TASK_TODO.md`.
> Lo terminado va al journal (`docs/JOURNAL/`), no aquí.

## flowkit: mejoras de campo

- [ ] **`lint-health --measure`: simular el gate REAL del repo**: además del conteo de hallazgos, leer el comando de gate de `package.json` (ej. `lint:strict --max-warnings 0`) y reportar si esas N violaciones **romperían el gate**, no solo cuántas hay. Origen: field-test dev tennispro: el `--max-warnings 0` solo apareció al EJECUTAR el cambio, no al leer la config (`warn` ahí == `error`); un `--measure` que simule el efecto lo cazaría solo. Prioridad: valioso pero puntual (solo al decidir encender una regla en repo con gate estricto), esperar más field-tests. `added: 2026-07-31`

- [ ] **`flowkit hooks` borra los jobs locales de `lefthook.yml`**: en 3 clones de `labs-ios-base` el `lefthook.yml` traía `remotes:` + `pre-commit: commands:` propios (swift-format sobre `*.swift`, check-localizations sobre `*.xcstrings`). Tras correr `flowkit hooks`, el archivo quedó solo con `remotes:` y `--verify` reportó 6 jobs (todos centrales): los checks por-commit de formato y l10n desaparecieron en silencio. Pre-push (`ship-config-gate`) cubre lint pero **no** l10n (no es llave del ship config), así que la verificación de localizaciones quedó solo en `make pre-deploy` manual. El blueprint documenta "the jobs under it are this repo's own", o sea que jobs locales son patrón soportado. Propuesta: mergear (remotes + preservar jobs locales) o al menos avisar antes de tirarlos. Dato: el bloque local usaba la sintaxis vieja `commands:`; si el parser de flowkit solo entiende `jobs:`, puede ser eso — revisar. Origen: field-test workspace-dpeluche-apps, 2026-11-21 (3 apps: personalnotes, translator, wardrobe). Prioridad: alta — pérdida silenciosa de checks. `added: 2026-11-21`

- [ ] **`flowkit hooks` como paso de afterclone**: un repo clonado de blueprint llega con `lefthook.yml` (remotes) pero sin el pin local de `core.hooksPath`: `flowkit hooks --verify` falla ("hooks NOT active") hasta correr `flowkit hooks` a mano dentro del clon. Cada app nueva necesita el paso manual. Opciones: que el quickstart/afterclone del blueprint lo corra cuando flowkit esté en PATH, o un modo workspace (`flowkit hooks --all`?) que cablee todos los repos de un directorio. Origen: mismo field-test. Prioridad: media — fricción por repo, no por sesión. `added: 2026-11-21`

- [ ] **`flowkit about`: remedio de orphan-stubs es de un solo camino**: en un repo sin `lefthook.yml` sugirió `flowkit unhook` (correcto si no se quieren hooks), pero para un repo que SÍ debe tenerlos el remedio es "commitea un lefthook.yml" o "corre flowkit hooks". Ofrecer ambos caminos según contexto (p. ej. si el repo tiene ship config o viene de un blueprint). Origen: mismo field-test — el workspace raíz se resolvió commiteando el lefthook del contenedor, no con unhook. Prioridad: baja, es UX de diagnóstico. `added: 2026-11-21`

- [ ] **Scope note de `docs/` en `--verify`**: el verify avisa "scope: NOT scanned at all — `(^|/)docs/` allowlisted by file TYPE: a REAL key pasted there commits clean". Correcto como transparencia, pero en workspaces índice cuya `docs/` guarda análisis, una llave real pegada ahí pasa limpio. Decidir si el allowlist debe ser más estrecho (solo patrones `*.example`/`sample`) o si basta la nota. Menor: considerar repetir el scope note también en `flowkit about`, no solo en `--verify`. Origen: mismo field-test. Prioridad: baja — ya está surfedeado en verify. `added: 2026-11-21`

- [ ] **`default-branch-nudge` dispara en commits iniciales legítimos**: "committing directly to 'main'" sonó en el commit inicial del scaffold de cada app recién clonada (sin remote, sin PR posible). Ruido no bloqueante; sugerencia: suprimir cuando el repo no tiene remote o tiene <2 commits, o respetar `default_branch_ok: true` desde el primer commit. Origen: mismo field-test. Prioridad: baja. `added: 2026-11-21`

- [ ] **Lo que sí funcionó (registrar como evidencia positiva)**: `ship-config-gate` cachó en el primer push real un `OrderedImports` roto por el rename del blueprint (3 apps); el panel canary de `--verify` detectó UNSEEN pre-wiring y ALL caught post-wiring; el loop verify→fix fue directo; el FLOW import y `strip-agent-attribution` corrieron solos. El gate se pagó solo el día 1. Origen: mismo field-test. `added: 2026-11-21`

## Deuda técnica (no bloqueante)

- [ ] **Scope-check del script de lint**: detectar un `eslint app/**` que deja carpetas (`convex/`, `scripts/`) sin lintear, señal para `flowkit lint-health`. Nice-to-have. `added: 2026-07-31`
- [ ] **Port de la suite a Linux/GNU**: `install`/`verify` fallan en Linux (el CI apunta a macOS por eso). Solo vale si algún consumer corre en Linux. `added: 2026-07-31`
