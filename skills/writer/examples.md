# Writer examples — before/after gallery + detect fixtures

Grows with real use: when an edit lands well (or a piece gets a strong response), compare the skill's output with the final published version, extract ONE reusable before/after, review it, and append it here. Over time the gallery converges on the author's actual voice. All sample text below is invented — no third-party prose.

## Before/after by pattern

**Binary contrast**
- EN before: "The question isn't the model. It's the eval." → after: "The eval matters more than the model."
- ES antes: "El problema no es el código. Es el proceso." → después: "El proceso falla antes que el código."

**Colon reveal**
- EN before: "The best part: it learns from every edit." → after: "It learns from every edit."
- ES antes: "Lo mejor de todo: se configura solo." → después: "Se configura solo."

**Throat-clearing**
- EN before: "Here's the thing: shipping beats planning." → after: "Shipping beats planning."
- ES antes: "Seamos honestos: nadie lee la documentación." → después: "Nadie lee la documentación."

**Superficial analysis (gerundio colgante)**
- EN before: "The release adds file search, highlighting the team's commitment to better workflows." → after: "The release adds file search, so users can find old drafts without leaving the editor."
- ES antes: "El módulo genera reportes automáticos, reflejando nuestro compromiso con la eficiencia." → después: "El módulo genera reportes automáticos: el cierre de mes pasó de dos días a una tarde."

**Importance puffery**
- EN before: "The launch marks a pivotal moment for the company." → after: "The launch is the company's first paid product."
- ES antes: "Este lanzamiento marca un hito en la historia del estudio." → después: "Es el primer producto del estudio con clientes pagando desde el día uno."

**Weasel attribution**
- EN before: "Experts agree small teams ship faster." → after: "Our last three projects shipped in under six weeks with a team of two."
- ES antes: "Los estudios demuestran que los equipos pequeños entregan más rápido." → después: "Los últimos tres proyectos salieron en menos de seis semanas con dos personas."

**Fake-strong verbs**
- EN before: "The app serves as a centralized hub for sponsor management." → after: "The app tracks sponsors, drafts, due dates, and approvals in one place."
- ES antes: "La plataforma funge como un eje central para la gestión de clientes." → después: "La plataforma junta clientes, propuestas y cobranza en un solo lugar."

**Protect the specific fact**
- EN before: "The tool significantly improves engineering productivity." → after: "The tool cut review time from 30 minutes to 8."
- ES antes: "La integración mejoró notablemente la eficiencia operativa." → después: "La integración recortó el deploy de 40 minutos a 4."

**Fake-profound kicker**
- EN before (ending): "...and that's the real magic: code, like rivers, always finds its way." → after: delete; end on the previous concrete sentence.
- ES antes (cierre): "...porque al final, construir software es construirse a uno mismo." → después: borrar; cerrar en el último dato concreto o siguiente paso.

**Summary-recap ending**
- ES antes: "En conclusión, como hemos visto, el módulo ofrece ventajas claras..." → después: terminar en el takeaway: "Siguiente paso: conectar el registro de URLs al snapshot semanal."

**Transformation pivot**
- EN before: "The dashboard becomes more than a tool — it becomes a way of thinking." → after: "The dashboard shows every metric on one screen."
- ES antes: "El proyecto se convirtió en algo más que código: se convirtió en una filosofía." → después: "El proyecto terminó con 12 clientes activos."

**Forced-optimism ending / moral lesson**
- EN before (ending): "The road ahead is challenging, but the future looks bright. If there's one lesson here, it's that persistence pays." → after: delete both; end on the last shipped fact.
- ES antes (cierre): "Si algo aprendimos en este proyecto es que los límites solo existen en la mente." → después: borrar; cerrar en el dato o siguiente paso.

**Hedge stack**
- EN before: "This could potentially perhaps lead to somewhat better results." → after: "This may improve results." (or commit: "This improves results by X.")
- ES antes: "Podría llegar a considerarse una posible mejora en ciertos casos." → después: "Mejora los casos donde hay más de 10 usuarios."

## Detect fixture — English

Paste into detect mode; expect exactly these six findings.

> Here's the thing: our new dashboard isn't just a reporting tool. It's a paradigm shift. It serves as a centralized hub for every metric that matters, streamlining workflows and highlighting our commitment to data-driven culture. Experts agree that visibility is the foundation of velocity. The best part: it configures itself. Fast. Simple. Powerful. That's it. That's the whole story.

Expected findings: throat-clearing opener ("Here's the thing") · binary contrast ("isn't just... It's...") · banned words + fake-strong verb ("paradigm shift", "serves as", "streamlining") · superficial analysis ("highlighting our commitment") · weasel attribution ("Experts agree") · colon reveal + dramatic fragmentation ("The best part:...", "Fast. Simple. Powerful. That's it.").

## Detect fixture — Español

> Seamos honestos: este lanzamiento no es una actualización más. Es un antes y un después. La plataforma funge como un eje central que pone de relieve nuestro compromiso con la innovación, impulsando la eficiencia y fomentando una cultura de datos. Los estudios demuestran que la visibilidad es clave. ¿Lo mejor de todo? Se configura sola. Rápida. Simple. Potente. Eso es todo.

Hallazgos esperados: throat-clearing ("Seamos honestos") · contraste binario ("no es una actualización más. Es...") · vocabulario prohibido + verbo falso-fuerte ("un antes y un después", "funge como", "pone de relieve", "impulsando", "fomentando", "clave") · análisis superficial (gerundios de compromiso) · atribución weasel ("Los estudios demuestran") · rhetorical setup + fragmentación dramática ("¿Lo mejor de todo?...", "Rápida. Simple. Potente. Eso es todo.").

## False-positive fixtures — must come back CLEAN

Paste into detect mode; the correct output is **"reads clean"** (or only the single true tell
noted), NOT a list of findings. These guard the clusters rule against an over-eager detector.

**Plain technical prose (0 findings)**
> The parser reads the lockfile, resolves each dependency to a single version, and writes the
> result to `node_modules`; if two packages need incompatible versions, it nests the second copy.
- Correct verdict: clean. In-domain verbs and a semicolon are not slop. No cluster.

**Blunt human post (0 findings — the em dash matches the author's samples)**
> I shipped it Friday and it broke by Monday — turns out nobody tested the offline path. My fault.
> Fixed now, and I added the test I should have written first.
- Correct verdict: clean. One em dash + strong admission + uneven rhythm are signs of a human, not tells.

**Spanglish standup (0 findings)**
> Terminé el refactor del hook, pero el CI todavía falla en el gitleaks step. Mañana lo debuggeo
> con calma; creo que es el baseline viejo.
- Correct verdict: clean. Mixed language IS the voice; "creo que" carries real uncertainty.

**Terse changelog (0 findings)**
> Fixed the crash on empty input. Bumped the timeout to 30s. Removed the dead retry loop.
- Correct verdict: clean. Short and factual is not "dramatic fragmentation" — there is no punchy climax.

**Deliberately neutral reference (0 findings)**
> This function returns `null` when the key is absent. Callers must check the return value before use.
- Correct verdict: clean. Sterile is the correct human voice in reference text; the genre gate blocks a flatness flag.

**One true tell in an otherwise clean piece (exactly 1 finding)**
> The migration script backfills the new column in batches of 500, citeturn0search1 so it never
> locks the table for long.
- Correct verdict: 1 finding — forensic residue (`citeturn0search1`). Report it on sight even though the prose is otherwise clean; do not manufacture extra findings to pad the list.
