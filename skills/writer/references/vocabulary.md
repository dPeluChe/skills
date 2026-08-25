# Writer — tiered ban-lists (load when checking words)

The strongest signal is **co-occurrence**, never a single word. Tiers encode that: a Tier-1
word flags alone; a Tier-2 word flags only when it clusters; a Tier-3 word never flags by
itself. This is what keeps the ban list from producing false positives on human writing.

Both lists rot — AI vocabulary rotates roughly quarterly. Review against the current
[Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)
each quarter and move words between tiers as their signal changes.

## English

**Tier 1 — flag on a single occurrence** (rarely written by a human unprompted):
delve, foster, leverage, utilize, facilitate, empower, tapestry, realm, beacon,
paradigm shift, game changer, ever-evolving, multifaceted, supercharge, underscore (figurative),
this is huge, this changes everything.

**Tier 2 — flag only at ≥2 per paragraph** (legitimate in isolation, slop in a cluster):
robust, seamless, streamline, crucial, pivotal, transformative, elevate, embark, harness,
vibrant, meticulous, intricate, paramount, testament, boasts, showcase / showcasing,
landscape (figurative), cutting-edge.

**Tier 3 — never flag alone; count only inside a cluster:**
key, important, comprehensive, various, ensure, enhance, significantly, essential, powerful.

**Often-empty phrases** (structural, treat as Tier 1 when they open or pad a sentence):
it's worth noting, it's important to note, at the end of the day, at its core, in today's world,
in the age of, when it comes to, in terms of, with regard to, the reality is, the truth is,
in order to, going forward, let's dive in.

**Era note (2025+ tells).** The current wave leans on: emphasizing, enhance, highlighting,
showcasing, ensuring — participles that fake analysis. Weight these higher today than a
2023-era list would; re-date the list when the wave shifts.

## Español

Es la lista que más se usa — mantenla a la par de la inglesa, no a la mitad. Cuando aparezca un
tell nuevo en un draft real, agrégalo aquí en su tier.

**Tier 1 — marcar con una sola aparición:**
sumergirse en, adentrarse en, fomentar, aprovechar el potencial, un antes y un después, tapiz,
panorama en constante evolución, es un testimonio de, pone de relieve, sin precedentes,
revolucionar, potenciar, allanar el camino, de vital importancia, abrir un abanico de posibilidades,
llevar al siguiente nivel, en la era de.

**Tier 2 — marcar solo con ≥2 por párrafo:**
robusto, sólido (figurative), vanguardista, de vanguardia, vibrante, impulsar (figurative default),
integral (as filler), juega un papel crucial, multifacético, meticuloso, desbloquear, abordar
(as filler: "abordar el desafío"), de la mano de, fluido (=seamless), holístico, dinámico,
innovador (as filler), sinergia.

**Tier 3 — nunca solo; cuenta solo dentro de un cluster:**
clave (as universal adjective), esencial, poderoso, integral (literal), garantizar, mejorar,
fundamental, significativamente, eficiente.

**A menudo vacías** (Tier 1 cuando abren o rellenan):
cabe destacar, es importante mencionar, hoy en día, en la actualidad, en el mundo de,
la realidad es que, a fin de cuentas, en definitiva, no es casualidad que, dicho esto,
en última instancia, sin lugar a dudas, de manera eficaz, en el corazón de, es innegable que.

## Model first-word tells (corroboration only, never proof alone)

Which word a model tends to open with. A lone opener is not evidence — but in a cluster it
corroborates. ChatGPT: "Certainly / Sure / Here's". Claude: "Based on / According to / Here's".
Gemini: "Absolutely / Of course". Treat as a Tier-3-strength signal.
