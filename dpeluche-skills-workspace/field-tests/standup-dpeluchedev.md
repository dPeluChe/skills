# Standup — dpeluche.dev · 11–18 Jul 2026

**TL;DR**: Semana de documentación, no de código de la app. Toda la actividad fue el sábado 18: limpieza mayor de docs obsoletos era-Irma (PR #10), actualización del wiki de perfil con Henri y portfolio HQ (PR #11), sync del GitHub profile, y purga de un artefacto con datos personales del historial. Queda abierto el research del repo público de skills (PR #12). Alerta: feedby.ai responde 503.

## Shipped

- **Higiene de docs (PR #10, merged)**: pase completo sobre docs desactualizados de la era Irma — README y CLAUDE.md adelgazados, 6 docs obsoletos movidos a `docs/ARCHIVED/` con convención unificada, `docs/README.md` reescrito.
- **Wiki de perfil actualizado (PR #11, merged)**: `docs/profile/03-projects.md` ahora incluye Hënri, el portfolio HQ y el experimento de bank-statement; `08-pending.md` al día.
- **Sync GitHub profile**: `docs/profile/06-social.md` §GitHub alineado con el perfil v2 live del repo `dPeluChe/dPeluChe`; se quitó el card de github-readme-stats (instancia pública pausada).
- **Purga de datos personales**: eliminado del repo y del historial un artefacto de prueba con detalle bancario (`e0dc2b3`).

## In progress

- **PR #12 (open)** — `docs/skills-repo-research`: análisis de mattpocock/skills, gstack, anthropics/skills y superpowers + propuesta de estructura, instalación por symlinks y roadmap en 3 fases para el repo público `dPeluChe/skills`. Pendiente de decisión/merge.

## New pendings

Agregados a `docs/TASK_TODO.md` esta semana (sección "Pendientes rápidos"):

- 🔴 **Revisar server de FeedBy** — feedby.ai da 503; es el link flagship en GitHub, LinkedIn y portfolio.
- **Evaluar `llms.txt` en dpeluche.dev** — resumen de marca para consumo de LLMs, fuente `docs/profile/`.
- **Spark: GitHub Pages** — el README anuncia `dpeluche.github.io/spark` pero Pages no está habilitado (404).
- **Mantener GitHub profile sincronizado** — regla de sync con `06-social.md` §5 cada vez que cambien claims editoriales.
- **(Opcional) Self-host de github-readme-stats** — si se quiere el card de vuelta, deploy propio en Vercel con PAT.

## Risks / blockers

- **feedby.ai en 503** desde el 18 Jul: el producto flagship enlazado en todos los canales públicos está caído. Es el pendiente más urgente y no es de este repo.

## Next

1. Levantar/diagnosticar el server de FeedBy (503).
2. Decidir sobre PR #12 y arrancar fase 1 del repo `dPeluChe/skills`.
3. Backlog mayor pendiente: extender el CMS de Iteris a `iterisProducts` (schema Convex ya especificado en TASK_TODO).

---
*Nota: la semana no tocó código de la app (Next.js/Convex sin cambios); fue enteramente editorial/documental. Evidencia: 9 commits del 18 Jul, PRs #10 y #11 merged, PR #12 open.*
