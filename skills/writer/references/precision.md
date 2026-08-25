# Writer, detect precision (load for detect, or when unsure whether to cut)

The detector's number-one failure is the **false positive**: flagging human writing because it
has one semicolon or one word from the ban list. A tell in isolation is noise. This file is what
keeps detect honest.

## Clusters, not isolated tells

One signal means nothing; a **cluster** is a confession. Perfect grammar is just clean writing;
perfect grammar plus rule-of-three plus "vibrant tapestry" plus a "Conclusion" heading is AI.
Before calling a passage slop, require **2 or more distinct tells**, or one Tier-1 word
co-occurring with one structural pattern. A lone Tier-3 word or clean punctuation is not a finding.

Two exceptions that ARE a finding on their own:
- **Any em dash.** Cut on sight, always report in detect. Almost no human writes with them, so a
  single em dash is enough. See Formatting slop in `SKILL.md`. This is a universal rule, not a
  per-author preference.
- **Forensic residue** (below): mechanical copy-paste leftovers, not style.

## What NOT to flag (leave it alone)

These read as slop to a nervous detector but are signs of a real writer:

- **Perfect grammar or punctuation by itself.** Clean does not mean generated.
- **A semicolon.** AI *underuses* semicolons, so their presence leans human. (An em dash is the
  opposite signal, and is always a finding.)
- **Legitimate in-domain jargon.** "weighted interval score" in a stats paper is precise, not
  slop. The tell is generic business jargon (leverage, ecosystem, landscape) leaking in, not
  correct technical vocabulary.
- **Mixed registers or code-switching** (Spanglish technical writing): that IS the voice.
- **Strong opinions, real hedges, digressions, self-interruption, admissions of not knowing.**
- **Numbers, named entities, specific dates, concrete examples:** the opposite of slop.
- **Uneven, emotional, or spoken rhythm.** Human cadence is bursty by nature.

If a passage's only "tell" is on this list, it is not a finding. Say the piece reads clean.

## Signs the writing is human (positive checks)

- **Burstiness:** sentence length varies (short, medium, long mixed), not a uniform march.
- **Survives compression badly:** see summary-loss below.
- **Fails the topic-swap:** it is tied to its actual subject, not portable boilerplate.
- **Carries a defensible stance:** an opinion someone could disagree with.

## Density tests (operational, cheap, no scripts)

Run these when a passage feels off but no ban word fires. They catch generic prose that every
ban list misses:

- **Summary-loss / unsummarizability.** Compress the passage to half. Strong writing loses
  concrete ideas immediately; slop shrinks without losing anything because it was scaffolding.
- **Topic-swap.** Replace the domain nouns with another field's. If the paragraph still reads
  fine, it says nothing specific: cut it or make it concrete. (unslop's one-liner: "if the
  sentence fits unchanged in another project's docs, it isn't saying anything.")
- **Sentence-load.** Every sentence should carry at least one of: claim, example, constraint,
  number, named entity, decision, tradeoff, mechanism, consequence, change of stance. A sentence
  that carries none is connective scaffolding: cut it or load it.

## Structural tells worth naming (beyond the core table)

These extend the patterns table in `SKILL.md`; each comes with the fix:

| Pattern | Smells like | Fix |
|---|---|---|
| False agency | "the data tells us", "the market rewards", "the decision emerges" | Name the human actor: who decided, who found |
| Diff-anchored writing | docs that narrate the change ("was added to replace", "now uses") instead of the thing | Describe the current state; the diff belongs in the commit |
| False ranges | "from startups to enterprises", "from X to Y" with no real scale between | State the actual span or drop it |
| Abstract-metaphor nouns | substrate, wedge, flywheel, north star, "API surface", primitive (figurative) | The concrete noun for what it is |
| Stacked historical analogies | "Apple didn't build Uber. Facebook didn't build Spotify..." for borrowed authority | Make the argument on its own merits |
| Aphorism / pull-quote formula | "X is the Y of Z", "the architecture of trust" | Say the literal claim |
| Wh-opener crutch | paragraphs that open "What makes this hard is...", "Why this matters is..." | Start on the claim itself |
| Copula avoidance | "serves as / stands as / boasts" instead of is/has | "is" or "has", or the concrete verb (also in the core table as fake-strong verbs) |
| No parataxis | staccato chains of short declaratives faking punch | Weave with subordinate clauses, or a semicolon where the thought is one thought |

## Forensic residue (always a finding, mechanical not stylistic)

Copy-paste leftovers from an LLM UI. No cluster needed, report on sight:

- **Citation tokens:** `citeturn0search0`, `contentReference[oaicite:0]`, `oaicite`
- **Tracking:** `utm_source=chatgpt.com` (or other model hosts) in pasted links
- **Placeholders left unfilled:** `[Your Name]`, `[insert X]`, `2025-XX-XX`, `[Company]`
- **Unicode obfuscation:** zero-width chars (U+200B, U+FEFF), Cyrillic or Greek homoglyphs sitting
  inside Latin words

These are tool tells, not voice; they never fall under the sample-outranks exception.

## Register gate for "sterile is also a tell"

The soul and personality checks apply **only in expressive genres**: posts, essays, opinion,
personal writing. In technical, reference, or legal text, plain and neutral IS the correct human
voice, and injecting stance or humor there is its own kind of slop. Gate before you flag flatness:
ask what genre this is first.
