# Standup: skills · 2 ago a 21 sep 2026 (registro retroactivo)

**TL;DR**: 36 PRs (#71 a #106) que no pasaron por el journal; esta entrada se escribe el 7 nov a partir de los PRs, porque la sesión original se perdió. Tres frentes: writer maduró hasta auditar output emitido (no la fuente) y el repo se limpió de em dashes e identidad hardcodeada; ship, hooks y verify ganaron gates más honestos (fresh clone, flake del canario con causa raíz); doctos y pm-tasks aprendieron a leer la estructura que el repo declara y a elegir el modo desde la prosa. flowkit 0.1.32 a **0.1.34**.

## Shipped

**writer y la higiene pública (14 a 27 ago):**
- Registro de negocio/cliente: quitar la energía de venta (#71).
- Capa de detección con precisión, routing de referencias y modo embebido (#74); em dash a escala con carve-outs, contenido congelado y source-first (#76); tiers en español derivados, no portados, y auditoría del output emitido (#77); carve-out de rangos numéricos, alcance por pares y checks de invariantes (#81); cuatro deltas de unslop (#85).
- Purga de em dashes e identidad hardcodeada en 7 skills (#75). La doctrina quedó en `docs/GUIDES/DESLOP_AND_HYGIENE_DOCTRINE.md` (#79, #83).

**doctos y pm-tasks:**
- doctos: repos de contenido no técnico y check derivado-vs-fuente (#78); templates bajo demanda (#80); estructura declarada en `.doctos.yml` (#101); anuncia la convención en el README del proyecto (#102); el repo la usa sobre sí mismo (#106).
- pm-tasks: tareas de proyecto separadas de actividades de proceso (#82); templates bajo demanda (#84); evidencia antes de archivar (#100); trackers externos como referencia genérica (#105).
- Ambos eligen el modo desde la prosa y por defecto el de solo lectura (#103).

**ship, kickoff, standup:**
- ship solo a petición, nunca por iniciativa propia (#86); gates en un clone fresco con chequeo de drift de fuente (#93); check "Tests in the diff" (#99).
- kickoff: boceto de arquitectura opcional (#87). standup: lente retro en el micro-standup (#88).

**flowkit (hooks, verify, stamp, lint-health):**
- Baseline de gitleaks honesto (#72, 0.1.33); nudge al commitear en la rama default (#73, 0.1.34).
- Flake de ~1/3 de la suite con causa raíz: input aleatorio del canario (#89); se quitó la rama probe-rot porque hacía pasar en CI un gate roto (#90); pase de simplify que encontró dos bugs más (#91).
- Hooks: ya no pisa el `hooksPath` global (#92); verify nombra el wiring stale y `flowkit hooks` avisa cuando lo sana (#94); sigue la indirección de husky (#97).
- stamp: newline final en el baseline (#95) y conteo `gitleaks:allow` que rompía la aritmética (#96).
- lint-health: reglas cubiertas, `--measure --list` y alcance del canario explícito (#98).
- README vuelve a ser landing; hooks y flowkit pasan a `docs/GUIDES/` (#104).

## Impact

- El pendiente abierto del 1 ago (relay manual entre agentes, fricción #1) se está resolviendo fuera de este repo: exegol implementa un inbox entre proyectos para hilos y dudas entre sesiones.
- Limpieza de ramas remotas mergeadas pendiente de ejecutar por Antonio (permiso de borrado remoto).
- Backlog en `docs/TASK_TODO.md` sin cambios: `--measure` simulando el gate real y deuda técnica.

**Status: DONE** (registro), main en #106, flowkit 0.1.34.
