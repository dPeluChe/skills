# Writer, English ban-lists (load when checking English words)

The strongest signal is **co-occurrence**, never a single word. Tiers encode that: a Tier-1
word flags alone, a Tier-2 word flags only when it clusters, a Tier-3 word never flags by
itself. This is what keeps the ban list from producing false positives on human writing.

For Spanish drafts, load `references/spanish.md` instead. It holds the complete Spanish
ban-lists, pattern examples, and detect fixture in one place.

Both language lists rot. AI vocabulary rotates roughly quarterly. Review against the current
[Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)
each quarter and move words between tiers as their signal changes.

**Tier 1, flag on a single occurrence** (rarely written by a human unprompted):
delve, foster, leverage, utilize, facilitate, empower, tapestry, realm, beacon,
paradigm shift, game changer, ever-evolving, multifaceted, supercharge, underscore (figurative),
this is huge, this changes everything.

**Tier 2, flag only at 2 or more per paragraph** (legitimate in isolation, slop in a cluster):
robust, seamless, streamline, crucial, pivotal, transformative, elevate, embark, harness,
vibrant, meticulous, intricate, paramount, testament, boasts, showcase, showcasing,
landscape (figurative), cutting-edge.

**Tier 3, never flag alone, count only inside a cluster:**
key, important, comprehensive, various, ensure, enhance, significantly, essential, powerful.

**Often-empty phrases** (structural, treat as Tier 1 when they open or pad a sentence):
it's worth noting, it's important to note, at the end of the day, at its core, in today's world,
in the age of, when it comes to, in terms of, with regard to, the reality is, the truth is,
in order to, going forward, let's dive in.

**Era note, 2025 and later tells.** The current wave leans on: emphasizing, enhance, highlighting,
showcasing, ensuring. These are participles that fake analysis. Weight them higher today than a
2023-era list would, and re-date the list when the wave shifts.

## Model first-word tells (corroboration only, never proof alone)

Which word a model tends to open with. A lone opener is not evidence, but in a cluster it
corroborates. ChatGPT: "Certainly", "Sure", "Here's". Claude: "Based on", "According to",
"Here's". Gemini: "Absolutely", "Of course". Treat as a Tier-3-strength signal.
