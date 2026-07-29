# Standup — dPeluChe/skills · 28-29 jul 2026 (ciclo fundacional flowkit)

**TL;DR**: de 6 skills sueltas a un sistema completo con CLI, hooks en 4 capas
y ciclo de field-feedback funcionando: 8 skills, flowkit 0.1.0→0.1.7 (7
releases en 2 días), 146 tests, 25 PRs (#11-#35), 3 field-tests externos
absorbidos (workspace 5 repos, trs, browv2).

## Shipped

- **ship + deploy-doctor** (#11-#12): cierre de PR con gates/evidencia y
  diagnóstico de infra — del brief del reviewer (~250 sesiones de corpus).
- **install.sh v2 + Makefile + flowkit CLI** (#13-#18): cadena de 2 saltos,
  `--check` doctor, comando global con PATH auto-configurado.
- **Hooks 4 capas** (#15, `hooks/`): pre-commit <2s (gitleaks/env/LOC),
  pre-push runtime-read del `## ship config`, commit-msg strip-attribution,
  guards del harness (git-guard, secret-guard) — más FLOW_CLAUDE.md (10 líneas).
- **0.1.1→0.1.6 field-feedback** (#21-#34): honestidad de wiring
  (`--verify` + canario por el hook EFECTIVO con warm-up anti-placebo),
  unhook, portabilidad --team (CLAUDE.local.md), ship config stack-aware con
  pre-fill de CI, gitleaks repo-local, hooks_skip declarable, output compacto,
  guard semántico por asignación.
- **0.1.7** (#35): install.sh 1503→113 líneas + 6 módulos `scripts/lib/`
  (<400 c/u); ship config del propio repo commiteado (`merge_policy: auto`,
  suite como gate mecánico). Wrappers globales extendidos al common-dir
  (worktrees ya no esquivan hooks).

## Evidencia

Suite 146/146 · shellcheck 0 · `flowkit 0.1.7 (c83b97a)` ·
verify PASS end-to-end con canario · instalado: workspace-dpeluche (5),
trs (--team + delegación pre-commit + skip declarado), browv2 (--team ×2
checkouts, PR #29 con `merge_policy: ask`).

## Lo aprendido (doctrina, pagada con incidentes reales)

**Lo declarado diverge de lo efectivo en silencio** — "sync ✔️" sin hooks
activos, canario verde con gate inerte, "build ok" con exit 2. Lo destapa
ejecutar la cosa real, no leer la config. Corolarios: suite verde ANTES de
cada commit (2 violaciones propias → ahora gate mecánico); la deuda de
tamaño se deposita, no se decide; acuerdo ≠ invariante (merge_policy es el
recordatorio; branch protection la cerradura). El sistema corrigió a sus
autores 6+ veces antes que a nadie — la única prueba real de que funciona.

## Next

- Feedback de uso de Antonio (ronda de repos, consumo real).
- browv2: revisión de sus 3 PRs (su hilo) · trs: #123 (suyo).
- Radar: CI backstop (gitleaks action) en repos de equipo.
