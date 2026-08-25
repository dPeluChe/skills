# Writer, purging em dashes at scale (load for a whole-repo or many-file sweep)

The em-dash ban is simple on one paragraph and dangerous across a repo. Every rule here comes
from a field run that broke real files. For a single draft you do not need this; for a sweep,
follow it exactly.

## Carve-out: an em dash is not always prose

Replace an em dash ONLY when it is punctuation inside a human-readable sentence. Leave it alone,
or convert it differently, when it is:

- **A numeric range: the highest-damage carve-out, and NOT optional to detect.** An em dash
  between two numbers or two years is a range, not punctuation. It goes to an **en dash** (`–`),
  which the editorial rules allow for ranges, NEVER to a comma, colon, or period. Getting this
  wrong corrupts a fact, not a style: `Earlier (2006 — 2015)` turned into `Earlier (2006: 2015)`
  four times in one CV, every time in a real employment date. This error is irreversible without
  going back to the source to recover the true years, so detect it first: any em dash flanked by
  digits (optionally with spaces) is a range.
- **An empty-value glyph / cell marker.** `{client.email || "—"}`, a table cell that shows "—"
  for "no data", a placeholder in a UI. Converting it changes what the interface renders. That
  is a bug, not a de-slop fix.
- **Inside code or a code comment.**  This skill edits prose, not code.
- **Inside a fence whose CONTENT is not prose.** The carve-out is about what the fence contains,
  not that it is a fence. A ```` ```text ```` (or no-language) fence holding publishable copy in
  the author's voice, LinkedIn entries staged for copy-paste, a bio, IS in scope: convert it, it
  is exactly the channel the rule targets. A fence holding code, shell, or structural templates
  with bracket-markers (`[What it is — one line]`) is NOT: leave it. Decide by content, not by the
  fence.

When in doubt about a given hit, render or read the surrounding context and ask "is this a
sentence a human reads, or a token a program emits?" Only the former is in scope.

## Context-to-replacement map (field-tested over ~90 conversions)

Pick the replacement by what the em dash is doing, not by a single global rule. This mapping was
stable across a real sweep:

| Context | Replacement |
|---|---|
| Range between two numbers or years (`2006 — 2015`) | **en dash** `–` (a range, not punctuation; never a colon/comma) |
| `**Label** — text` (label then elaboration) | colon: `**Label**: text` |
| Status inside a table cell | comma (a colon reads badly in a cell) |
| Parenthetical between a pair of dashes, **within one clause** (`the tool —fast— shipped`) | parentheses |
| Apposition mid-sentence | colon |
| Trailing / closing clause | comma |
| Two independent clauses joined | period (or semicolon if the thought is one thought) |

## At-scale mechanics (the part that breaks repos)

- **A pair is only a pair inside one clause, and pairing is never inferred by counting.** Two em
  dashes are a parenthetical pair (`the tool —fast— shipped`) ONLY when they sit in the same
  clause. Two em dashes spread across a multi-sentence paragraph are two INDEPENDENT marks, not a
  pair, no matter whether they are on the same line or different lines. The failure is about
  scope, not line count: a same-line multi-sentence paragraph breaks just as badly. Real case, all
  on one line, wrongly wrapped as a pair: `Says what was built, how, and why — in that order. [...]
  Spanish-native writing in English — short sentences` became `Says what was built, how, and why
  ( in that order. [...] writing in English ) short sentences`. Judge each dash by its own clause;
  never turn "there are two dashes here" into "these two are a pair".
- **Never sweep paired punctuation with a multiline regex.** A pattern that matches `—text—` and
  turns it into parentheses crosses boundaries and invents pairs that never existed. In markdown
  this is vicious: two consecutive table rows that each end in an em dash look like one open-close
  pair to the regex, so it merges unrelated rows into corrupted content.
- **Edit line by line, with a single-match assertion.** Replace one occurrence at a time, and
  assert the old string matches exactly once in the file before applying (the way a safe
  find-and-replace refuses an ambiguous match). One dash, one decision, one edit.

## Invariant checks (mandatory, not a suggestion)

Measuring what you changed does not tell you whether you broke something. Counting balanced
parentheses passes a corrupted table (the bad edit added one open and one close). Counting "how
many em dashes remain" passes too, because the conversion DID happen, it just converted the wrong
character. Both self-checks report clean over broken content.

What catches the damage is comparing, against the previous version, the things a punctuation edit
must NEVER alter. Run these as a required last step of any sweep, diffing the file against its
pre-sweep state:

- **The set of years and numbers** is unchanged. (Catches a range collapsed into `2006: 2015`.)
- **Table shape**: the column count per row and the number of rows are unchanged. (Catches merged
  or split rows.)
- **Link targets** (URLs, hrefs) are unchanged.
- **Rendering**: the file still renders as the same structure (table stays a table, list a list).

If any invariant moved, a punctuation sweep changed something it never should have: stop and fix
that hunk before continuing. This is stronger than "verify by rendering" because it names the
specific things to compare rather than trusting a visual scan.

## Audit the emitted output, not the source

To count a tell, grep the artifact that actually reaches a reader, not the source files. The
source lies in both directions:

- **It over-counts.** Many em dashes (or slop words) live in doc-comments, dead code, or examples
  that never render. In one field case, 70% of a source file's em dashes were in Rust doc-comments
  that never reached the emitted prompt. Cleaning them is wasted work.
- **It under-counts.** Tells enter the output by interpolation from places a source grep never
  looks: a `Cargo.toml` / `package.json` `description` field spliced into a header, a config value,
  a template variable, generated tables. In the same case, the installed artifact had exactly 9 em
  dashes (the right number to fix) while the source had 29 (the wrong target).

So: render or generate the real output and grep THAT. When the artifact is a prompt, check the
installed prompt; when it is a page, check the rendered page; when it is a report, check the emitted
report. This is the general form of "verify by rendering".

**One value can live at several layers, so search for the value, not the file.** In any framework
with layered configuration (Next.js metadata, i18n catalogs, theme tokens), the same string is
often defined at more than one level: a root `layout.tsx` title AND a per-route `page.tsx` that
overrides it. A field sweep mapped 3 occurrences of a title and the real count was 6, because each
route redefined its own metadata. Grep the whole tree for the VALUE (the actual string), not the
one file you expect it in. This is the mirror of the debugging rule "if a change does not take
effect, the value is defined in more than one place": here the extra definitions are extra copies
of the tell.

## Git verification traps

- **`git mv` inflates the "did I add em dashes?" diff.** A moved file counts its ENTIRE body as
  added lines, so a diff-scoped grep for `—` can jump from 10 real additions to 68. Exclude moved
  and renamed files explicitly when counting (`git diff --diff-filter=M` for true modifications,
  or check moved files against their pre-move content), or you will chase phantom hits.
- **Count against the working tree, not just the diff,** for the final check: `grep -rn "—"` over
  the target paths, minus the carve-out contexts above, is the ground truth that a file is clean.

## Order of operations for a repo sweep

1. Map the surfaces (see SKILL.md repo-wide detect), ordered source before derived.
2. Skip frozen content (`docs/JOURNAL/`, `docs/ARCHIVED/`, changelogs): those keep their em
   dashes, because rewriting a record falsifies it.
3. Fix the source surfaces first, then the derived ones.
4. Per file, replace line by line with the map above, honoring the carve-out (ranges to en dash, non-prose fences and glyphs untouched).
5. Run the invariant checks against each file's pre-sweep version (years/numbers, table shape, link targets, row count). Any invariant that moved is breakage: fix it.
6. Grep the working tree (excluding carve-out contexts and moved files) to confirm no prose em dashes remain.
