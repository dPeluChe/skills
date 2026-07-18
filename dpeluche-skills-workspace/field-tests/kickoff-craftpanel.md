# Kickoff — Moliniart (labs-craft-panel)

**One-liner**: Dashboard de gestión + tienda pública para Moliniart, negocio de papelería artesanal personalizada (productos, inventario, cotizaciones, órdenes, clientes, compras, equipos, costos).
**Stack (real)**: Vite + React 18 + TypeScript · Convex (backend real-time, ~25 módulos) · shadcn/ui + Radix + Tailwind · React Router v6 · TanStack Query/Table · Zod + react-hook-form · Auth propia JWT + bcryptjs · Vitest. Dev server en puerto 3006.
**Activity**: último commit 2026-07-13 (hace 5 días) · rama actual `feat/quote-007-008-settings-convex-mxn` con **3 commits sin push** (sin upstream, sin PR) · working tree limpio · 0 PRs abiertos · ~30 ramas remotas (solo `chore/docs-and-deps` sin mergear a main).
**Status read**: Activo, pausado a mitad de entrega — la rama de pricing quedó terminada localmente pero nunca se publicó.

## Core modules

- `convex/cotizaciones.js` + `convex/businessSettings.js` — el corazón actual: motor de pricing MXN (`calcularDesglose`, `calcularCostosInternos`), settings singleton en Convex.
- `convex/` (~25 módulos: productos, inventario, ordenes, clientes, compras, equipos, gastosFijos, crm, crons…) — toda la capa de datos; `_auth.js` lo importan 13 módulos.
- `src/components/admin/` — managers y creation views por dominio (Quotes, Products, Inventory, Orders, Clients, Equipos, FixedCosts, Purchases).
- `src/hooks/` — `use-auth`, `useBusinessSettings`, `useQuoteCreation`, `useProducts`… puente Convex ↔ UI.
- `src/components/ui/` (shadcn) + `utils.ts` — base compartida (button/card importados por 80+ archivos).

## Where things stand

**El "¿dónde me quedé?"**: la rama `feat/quote-007-008-settings-convex-mxn` tiene 3 commits listos que main no tiene, y **no está en origin**:

1. `fa2369a` — businessSettings en Convex (MXN) + retiro del motor USD muerto (QUOTE-007/008)
2. `b8d6005` — mano de obra y costos fijos reales en cotización (QUOTE-004 parcial)
3. `9f8c2fd` — redondeo del total al peso configurable (QUOTE-003 residual)

El siguiente paso natural es **push + PR a main**. El TASK_TODO fue actualizado en el mismo commit final, así que backlog y código están sincronizados.

Contexto reciente (últimos ~15 commits, PRs #24–#29): sprint de homologación de números de cotización — schema del modelo real (MODEL-001), builder cableado al modelo real, flags en formularios, descuento/anticipo/términos, perfil comercial CRM, y hoja de revisión de insumos (DATA-002). Todo mergeado a main excepto la rama actual.

Pendientes fuertes del backlog (P0): GASTOS-001 (histórico de recibos), DATA-002 (capturar 207 insumos), DATA-001 (110 cotizaciones reales como productos), QUOTE-009 (limpiar componentes mock del builder), QUOTE-010 (vista pública compartible), y PERF-003/004/005 (queries Convex).

## Reality-check findings

| Doc claims | Code shows | Severity |
|---|---|---|
| `README.md`: "CraftPanel v2.4.3 · Production Ready · Completitud 100%" | package.json es `moliniart-dashboard`; branding es Moliniart; hay backlog P0 activo de pricing — el README quedó congelado pre-rename | Alta |
| `README.md`: "Bundle 200KB gzipped" | TASK_TODO (fuente fresca): "bundle estable ~30KB gzip" | Baja |
| `CLAUDE.md`: "Data Layer → Mock Data en `src/data/mocks/`" | `src/data/mocks/` no existe; la capa de datos es Convex (~25 módulos) y CLAUDE.md no documenta Convex ni auth JWT | Alta |
| `CLAUDE.md`: puerto 3006 y scripts npm | vite.config.ts confirma 3006; scripts coinciden | ✅ OK |

## Routed findings

**For /doctos**:
- README.md desactualizado: nombre CraftPanel (repo ya es Moliniart), versión/métricas/estado congelados pre-rename.
- CLAUDE.md describe una arquitectura con mocks que ya no existe; falta Convex, auth y flujo actual.
- Archivos sueltos en root: `CRUSH.md`, `context.json`, `bundle-analysis.html`, `create-admin.js`, `create-admin-simple.html`, `debug-auth.html`, `debug-auth-simple.html`, `package.json.convex-dependencies` — debris de debug/análisis fuera de docs/scripts.
- (Positivo: `docs/` ya sigue la estructura estándar ARCHITECTURE/FEATURES/GUIDES/RESEARCH/ARCHIVED.)

**For /pm-tasks**:
- QUOTE-003 (residual), QUOTE-007 y QUOTE-008 con todos los checkboxes ✅ → listos para archivar a TASK_COMPLETED.
- QUOTE-004 casi completo (queda 1 item que depende de QUOTE-009) → posible split/renombre.
- Header dice "Última actualización: 2026-07-10" pero el archivo se editó 2026-07-13 → fecha stale.

## Suggested next actions

1. **Push + PR de `feat/quote-007-008-settings-convex-mxn` a main** — trabajo terminado que solo existe local; es el riesgo más alto ahora mismo.
2. Correr `/pm-tasks` para archivar QUOTE-003/007/008 completados y limpiar el header del TODO.
3. Correr `/doctos` para README/CLAUDE.md desactualizados y el debris del root.
4. Retomar backlog P0: DATA-002 (insumos con la admin) o QUOTE-009 (decidir componentes mock del builder) son los siguientes desbloqueadores.
