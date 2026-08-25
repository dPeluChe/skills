# Writing and doc-hygiene doctrine

Field-tested principles behind the `writer` and `doctos` skills. This is the WHY, kept in one
place so it survives across sessions and is shareable. It does not restate the rules; it points to
where each is enforced. When a principle and a skill disagree, the skill is the source of truth and
this doc is stale: fix it.

All of this came from applying the rules at scale and watching them break, not from theory.

## Em dashes are banned, universally

Almost no human reaches for an em dash while writing, so it is the single strongest "an AI wrote
this" marker and it reads badly to nearly everyone. The ban is universal, not a per-author
preference: it holds for prose everywhere, including this repo's own docs, the skills' own text,
and Claude's replies. Enforced in `skills/writer/SKILL.md` (Formatting slop) and declared for
Antonio's content in `dpeluche.dev/docs/profile/10-editorial-rules.md`.

Carve-out: an em dash is not always prose. A UI glyph or empty-value marker (`{x || "—"}`), a
cell marker, code, and code comments are out of scope; converting them is a bug. See
`skills/writer/references/em-dash.md`.

## Audit the emitted output, not the source

To count a tell, grep the artifact a reader actually gets (rendered page, generated report,
installed prompt), never the source. Source over-counts (tells in doc-comments or dead code that
never render) and under-counts (tells interpolated from a `package.json` / `Cargo.toml`
description spliced into a header). This is the general form of "verify by rendering". Enforced in
`skills/writer/references/em-dash.md` and the repo-wide detect steps of `writer/SKILL.md`. One
value can also live at several config layers (a Next.js title in `layout.tsx` and again in a route
`page.tsx`): grep the tree for the value, not the one file you expect it in.

## Verify invariants, not what you changed

Measuring what you edited cannot tell you whether you broke something. A clean em-dash count and
balanced parentheses both pass over corrupted content, because the edit happened, it just changed
the wrong character. What catches damage is comparing, against the pre-edit version, the things a
punctuation edit must never touch: the set of years and numbers, table shape (columns per row, row
count), and link targets. A range is the sharpest case: an em dash between two years is a range and
goes to an en dash, never to prose punctuation; `2006 — 2015` turned into `2006: 2015` is a
corrupted fact, irreversible without the source. Run invariant checks as a required last step, not
a suggestion. Enforced in `skills/writer/references/em-dash.md`.

## Structure is durable; words rotate

Structural tells (binary contrast, rule of three, false agency, additive escalation, fake-profound
kicker) come from how models are trained and do not expire. Word ban-lists rotate quarterly with
the model. Weight structure as the primary signal, word-lists as secondary. A single structural
rule does more than ten banned words. Enforced in `writer/SKILL.md` (patterns table is primary)
and `references/vocabulary.md`.

## Spanish slop is not a port of English slop

English slop has its own rare vocabulary (delve); Spanish slop reuses ordinary words (impulsar,
abordar, integral), so a single Spanish word is a weaker signal. Raise the co-occurrence threshold
in Spanish and lean on structure. Enforced in `skills/writer/references/spanish.md`.

## Name the destination, not just the ban

A rule that says what to avoid but not what to put does not land. The em-dash rule works because it
names the replacement (comma, colon, parentheses, period, "and"); the comments rule worked once it
named where the long explanation goes. Always pair a ban with the replacement or the concrete fact,
ideally a BAD/GOOD pair. Applies to any rule added to any skill.

## Prompt surfaces vs linter surfaces

On a prompt, a long list of forbidden words is a list of pink elephants: enumerating twenty banned
words puts twenty in the model's attention. On prompt surfaces keep a few words plus a positive
instruction; the cut is by mechanism, not token budget. On a linter or reference surface the full
list is fine. This is also why the skills use reference routing: the always-loaded `SKILL.md` stays
lean and the long lists live in references loaded on demand.

## Frozen content is never rewritten

`docs/JOURNAL/` and `docs/ARCHIVED/`, changelogs, and commit messages are born-historical: they
record a moment. Editing them, even to remove a tell, falsifies the record. Detect may note; edit
skips. Enforced in `writer/SKILL.md` (Boundaries) and `doctos/SKILL.md`.

## Not every repo's documents are docs about a system

Some repos have the documents AS the product (a bylaw, contracts, a corpus). There the default
`docs/` layout, the technical taxonomy, and UPPERCASE English folders do not apply: organize by
domain and use readable names for the actual audience. Detection: no dependency manifest plus more
than half the files are documents. Enforced in `skills/doctos/SKILL.md` (Repo type).

## Derived artifacts drift from their source

A file that is an export of a source (a `.pdf` from a `.md`, a `.d.ts` from a `.ts`) drifts
silently when the source changes and the export is not regenerated. Cheap check: same base name,
different extension, compare mtime and size. This is the general form of the stale-claims check and
applies to code and content alike. Enforced in `skills/doctos/SKILL.md` (AUDIT detection).

## Not every checkbox is a project task

A `- [ ]` can be a project task (work we do in the repo, closed by a commit, archived as "what was
built") or a process activity (a real-world errand people do outside the editor, closed when
someone went somewhere: request access, call an office, collect signatures, schedule a security
review). Mixing them drowns the real backlog under errands and makes the monthly archive lie about
what shipped. Keep one `TASK_TODO.md` for project tasks only; a process checklist lives next to the
record it supports and is never archived to `YYMM.md`. Applies to code repos too. Enforced in
`skills/pm-tasks/SKILL.md`.

## How to validate a de-slop skill

Run real text through it and count the tells in the OUTPUT, not in the rules. Reviewing intent is
not enough; execute and measure the emitted artifact. A good corpus is real text with a mix of
human and agent writing, unlabeled.

## Growth discipline

Every rule above earns its place by preventing a real failure or removing a real ambiguity, not by
being complete. Keep the always-loaded `SKILL.md` lean and push detail into references loaded on
demand (this is why writer's core barely grew while its capability multiplied). If a skill's single
file approaches the repo LOC limit (`doctos` is the one to watch), split it into references the way
`writer` is split.
