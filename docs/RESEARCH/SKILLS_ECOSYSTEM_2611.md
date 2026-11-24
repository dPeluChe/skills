# Research: ecosistema de skills (nov 2026)

> Estado: **en pausa, para retomar**. Investigación hecha el 7 nov 2026 (stars y fechas vía GitHub API ese día). Nada de esto está implementado todavía; la sección final es la propuesta. Se irá ampliando con más fuentes.

Tres frentes: anti-slop de UI y gusto en páginas, la skill de seguridad de Cloudflare, y colecciones de skills con tracción.

## 1. Anti-slop de UI y gusto en páginas

El espacio está maduro. La conclusión es **adoptar, no construir desde cero**.

| Fuente | URL | Stars / push | Qué hace | Veredicto |
|---|---|---|---|---|
| Anthropic frontend-design | github.com/anthropics/skills/tree/main/skills/frontend-design | 188k (repo) / nov | Un SKILL.md: dirección anclada al tema, 5 "clusters" de IA para calibrar, plan, revisión del plan, build, autocrítica con screenshot | El mejor enunciado corto de gusto. Solo genera, no detecta |
| Impeccable | github.com/pbakaus/impeccable | 105k / nov | 24 comandos (critique, audit, polish...), `PRODUCT.md`/`DESIGN.md`, **detector determinista de 62 reglas** (`npx impeccable detect <src\|url> --json`), hook post-edit | El más fuerte. El detector se reutiliza tal cual |
| heydamir/unslop | github.com/heydamir/unslop | 11k / nov | Audita con `signs.md`, triage heavy/light/no-slop, 5 líneas de dirección, **para y pide aprobación**, 9 pases ordenados, re-render | El más parecido a writer. `signs.md` es el mejor catálogo legible |
| taste-skill | github.com/Leonxlnx/taste-skill | 111k (no verificado) / nov | Opinionado: house rules, gate de navegador en Stop hook | Se apropia del stack y del estilo; mal fit para landings con dirección propia |
| ui-ux-pro-max | github.com/nextlevelbuilder/ui-ux-pro-max-skill | 146k (no verificado) | Base de estilos, paletas y fuentes | Amplitud, no gusto. No inspeccionado a fondo |
| Vercel Web Interface Guidelines | github.com/vercel-labs/web-interface-guidelines | 1.1k | Piso de interacción, a11y, formularios | Piso de calidad, no gusto |
| pixelslop | github.com/gabelul/pixelslop | 9 | 26 patrones visuales + 16 de fuente, cada uno marcado mecánico o de juicio | Chico, pero la separación mecánico/juicio sirve |

Licencias: revisar el LICENSE de cada repo antes de copiar nada (impeccable, taste-skill y unslop no declaran SPDX en GitHub; unslop dice CC-BY-4.0 en su frontmatter).

### Catálogo de señales (resumen)

- **Color y superficie**: gradientes violeta a azul, texto con gradiente, glows y halos, glassmorphism, crema con acento terracota, negro con un solo acento ácido, fondos de grilla fina.
- **Tipo**: Inter, Geist, Space Grotesk, serif itálica gigante, jerarquía plana (menos de 1.25x entre pasos), eyebrow en mayúsculas sobre cada heading, pill "Introducing X 2.0", pesos 800 a 900.
- **Layout**: grillas idénticas de 3 o 4 cards, cards dentro de cards, ícono en tile redondeado sobre cada heading, un solo radio y una sola sombra suave en todo, todo centrado, bloque de métrica gigante, numeración 01/02/03 sin secuencia, valores arbitrarios de Tailwind, todos los botones primarios.
- **Íconos y emoji**: emoji en nav, headings o cards; destellos junto a todo lo que es IA; badges "New" y "Beta".
- **Movimiento**: fade-and-slide en cada sección, hover lift en cada card, easing con rebote, marquees, parallax.
- **Copy y prueba social**: "Supercharge your workflow", "Trusted by 10,000+ teams", muros de logos y avatares sin fuente, palabras de hype, flecha en cada CTA. (Esta parte ya es territorio de writer.)
- **Visuales**: blobs 3D, robots y cerebros brillantes, UI falsa con datos placeholder.

Fuentes del catálogo: impeccable, unslop `signs.md`, los clusters de frontend-design, pixelslop, prg.sh (Why your AI keeps building the same purple gradient website), dev.to/alanwest (blame Tailwind's indigo-500). Varias son blogs de opinión, no datos medidos.

### Cómo codifican el gusto los buenos

1. Un paso de **dirección antes del código** (tokens, roles tipográficos, wireframe; o 5 líneas que prohíben "clean / modern / sleek / minimal / premium").
2. **Gastar la audacia en un solo lugar**: un elemento brillante, cromo callado.
3. **Nombrar los defaults en vez de prohibirlo todo**: cada señal es legítima si el brief la pide (igual que los carve-outs de writer).
4. **Triage antes de editar**: nunca rediseñar una pantalla que ya está bien.
5. **Juzgar lo renderizado, no la fuente** (igual que el "audit emitted output" de writer).
6. **Archivos de contexto** (`DESIGN.md`) contra los que el detector marca fuentes, colores y radios fuera de sistema.

Lo mecánico (fuentes, clases de gradiente/backdrop, sombras glow, emoji, easing, valores arbitrarios, contraste, cards anidadas) se puede chequear; lo de juicio (hero genérico, secciones idénticas, "podría ser de cualquier producto") no.

## 2. Seguridad: cloudflare/security-audit-skill

- Repo: github.com/cloudflare/security-audit-skill (MIT, creado 18 jun 2026, último commit 14 sep). Post: blog.cloudflare.com/build-your-own-vulnerability-harness.
- Install: `npx skills add https://github.com/cloudflare/security-audit-skill --skill security-audit [--global]`.
- **General**, no específica de Cloudflare: cualquier lenguaje, cualquier agente.
- Dos modos: **guidance** (default, no escribe archivos) y **full audit** (solo si se pide explícito).
- Full audit en 6 fases: reconocimiento (arquitectura + `coverage-ledger.json`), caza con subagentes aislados por unidad del ledger, validación por un verificador fresco que intenta desmentir, validación de `findings.json` contra esquema, re-verificación independiente, reportes.
- Veredictos `confirmed` / `needs_validation` / `rejected`; solo los confirmados llevan severidad. Una defensa en profundidad faltante cuando otra capa ya bloquea es nota de hardening, no vulnerabilidad.
- Tamaños `quick` / `standard` / `deep`, scope por paths o por diff entre refs, presupuesto de llamadas. Las corridas se acumulan (Cloudflare: una corrida encuentra como la mitad de lo que encuentran varias).
- Ejecuta código del objetivo solo en sandbox sin red; output fuera del repo.

| Herramienta | Alcance | Costo |
|---|---|---|
| `/security-review` (Claude Code, built-in) | Cambios pendientes de la rama | Bajo |
| anthropics/claude-code-security-review (Action) | Diff del PR, comenta en el PR | Bajo por PR |
| cloudflare/security-audit-skill | Repo completo o diff | Alto (muchos subagentes, horas) |
| trailofbits/skills | Una skill por trabajo (differential-review, fp-check, insecure-defaults, supply-chain...) | A elección |

Fit: **no como gate por PR** (demasiado lenta). Instalar tal cual y correr quick/standard en repos con auth, MCP o datos multi-tenant antes de deploys grandes, guardando los ledgers.

## 3. Colecciones con tracción

| Repo | Stars | Foco |
|---|---|---|
| github.com/mattpocock/skills | 317k | Ingeniería y productividad: grill-me, handoff, triage, to-spec, tdd, git-guardrails. Domina el top de skills.sh |
| github.com/obra/superpowers | 314k | Metodología: brainstorm, plan, subagent-driven dev, TDD, verification-before-completion |
| github.com/anthropics/skills | 189k | Referencia + skill-creator con harness de evals |
| github.com/garrytan/gstack | 141k | 60+ skills de roles: office-hours, plan-*-review, ship, land-and-deploy, retro, learn, context-save, careful/freeze |
| github.com/addyosmani/agent-skills | 114k | 25 skills de ciclo de ingeniería + el sistema de evals más completo |
| github.com/cursor/plugins/tree/main/pstack | 15.6k (monorepo) | **poteto (Lauren Tan)**. `/poteto-mode` con 23 playbooks + ~34 skills + 22 principles como skills. Instalable en Claude Code: `/plugin marketplace add cursor/plugins`, `/plugin install pstack@cursor-plugins` |
| github.com/vercel-labs/skills | 38k | `npx skills add owner/repo`, instalador multi-agente; alimenta skills.sh |
| github.com/JamsusMaximus/growth-agents | 70 | Growth OS: standup, retros, experiment log, skill-iterator |

Ojo: `flowkit-labs/skills` existe en skills.sh (mismo nombre que nuestro flowkit) con installs que no cuadran con sus stars.

### pstack: lo que más aporta

| Skill | Qué hace | Relación con lo nuestro |
|---|---|---|
| `/correct` | Mina el historial buscando errores que se repiten y corrige cada uno en el nivel más alto que funcione: arquitectura, tipos, lint/CI, tests, docs al final. Tabla regla a enforcement | Es la filosofía de flowkit (hook antes que `.md`). Mejor loop de aprendizaje que el learn de gstack |
| `/reflect` | Convierte la receta de una tarea larga en edición de skill | Pareja de `/correct` |
| `/interrogate` | Varios modelos intentan romper un diff; solo quedan hallazgos que una corrida demuestra | Idea para el quality pass del skill de PR |
| `/blast-radius` | Qué más rompe un cambio chico, probado corriendo código | Skill de PR o retro de standup |
| `create/maintain-verification-skill` | Skill de verificación por proyecto con mapa de features | El skill de PR podría exigirla si existe |
| playbook `eval` | Evals a ciegas: el evaluado no sabe que lo evalúan, juez de otra familia de modelos, se califica desde transcripts, no autorreporte | Diseño para nuestra fase de evals |
| `/recall`, `/ketchup` | Reanudar contexto | Se pisa con kickoff/standup: comparar, no adoptar |
| `/unslop`, `/technical-writing`, `/no-comments` | Prosa y comentarios | Se pisa con writer: comparar catálogos |
| `/sharpen`, `/in-your-own-words` | Antes del código | Cubre el hueco de "planear y cuestionar" |

### Patrones estructurales

- mattpocock: descripciones muy cortas y `disable-model-invocation: true` en skills deliberadas; ADRs en `.agents/adr/`, ideas rechazadas en `.out-of-scope/`.
- gstack: cada `SKILL.md` se genera desde `.tmpl` con secciones compartidas y un check de CI de que está al día. pstack hace lo mismo para su copia de Claude Code.
- superpowers / gstack: instalación multi-agente con niveles por host (full, experimental, instruction-only).

### Evals: tres niveles en la práctica

1. **Rúbrica de autochequeo** (nuestro `skills/writer/eval.md`): barato, no es testing.
2. **Trigger + comportamiento**: skill-creator (`evals.json` con prompt y `expectations[]`); addyosmani en tres niveles: estructural en CI, **routing léxico en CI con piso de 95%** (detecta descripciones que se pisan), comportamiento con `claude -p` headless en un repo desechable, más casos de "presión" (prisa, costo hundido, autoridad). `claude plugin eval` corre cada caso con y sin el plugin (según addyosmani, no verificado).
3. **Evals vivos pesados**: superpowers (sesiones reales en tmux con actor y verificador), gstack (`SKILL_EVAL_CONTRACT.md` con brazos antes/después/sin-skill), pstack (a ciegas, juez de otra familia).

## Propuesta (para decidir al retomar)

Prioridad sugerida:

1. **Evals**: empezar por el nivel gratis de addyosmani (routing léxico en CI sobre las descripciones de kickoff/standup/pm-tasks/doctos) y `evals.json` de skill-creator para el skill de PR y kickoff. Diseño a ciegas de pstack para los de comportamiento.
2. **Loop de aprendizaje al estilo `/correct`**: cada error repetido termina en un hook, un lint o un test de flowkit, no en un `.md`. Con aprobación una por una.
3. **Skill de PR**: tres veredictos (Cloudflare), verificador adversarial o `/interrogate` en el quality pass, sugerir `/security-review` cuando el diff toque auth/MCP/webhooks/mutaciones, `/blast-radius` opcional.
4. **Anti-slop de UI**: probar el detector de impeccable en una landing real; generar con frontend-design. Si hace falta algo propio, una `references/ui.md` delgada al estilo writer (detect vs edit, carve-outs, audit de lo renderizado) que delegue lo mecánico a impeccable. Nuestra ventaja: copy en español vía writer.
5. **Seguridad**: instalar la de Cloudflare sin modificar y correr una auditoría quick en un repo con auth y MCP como prueba.
6. **Guard "freeze"** en flowkit para limitar ediciones a un repo.
7. Planear antes del código (grill-me, `/sharpen`) para specs y propuestas.
8. Fuera: handoff entre sesiones (lo cubre el inbox de exegol) y por ahora el "mapa de proyecto" estilo Clarity (en hold).

Para probar barato antes de diseñar: instalar pstack como plugin y usar `/correct` y `/interrogate` en un repo.
