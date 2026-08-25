# Writer, purging em dashes at scale (load for a whole-repo or many-file sweep)

The em-dash ban is simple on one paragraph and dangerous across a repo. Every rule here comes
from a field run that broke real files. For a single draft you do not need this; for a sweep,
follow it exactly.

## Carve-out: an em dash is not always prose

Replace an em dash ONLY when it is punctuation inside a human-readable sentence. Leave it alone,
untouched, when it is:

- **An empty-value glyph / cell marker.** `{client.email || "—"}`, a table cell that shows "—"
  for "no data", a placeholder in a UI. Converting it changes what the interface renders. That
  is a bug, not a de-slop fix.
- **Inside code or a code comment**, or inside a fenced code block. This skill edits prose, not
  code.
- **A minus sign or a range glyph in code / data** (rare, but check before touching).

When in doubt about a given hit, render or read the surrounding context and ask "is this a
sentence a human reads, or a token a program emits?" Only the former is in scope.

## Context-to-replacement map (field-tested over ~90 conversions)

Pick the replacement by what the em dash is doing, not by a single global rule. This mapping was
stable across a real sweep:

| Context | Replacement |
|---|---|
| `**Label** — text` (label then elaboration) | colon: `**Label**: text` |
| Status inside a table cell | comma (a colon reads badly in a cell) |
| Parenthetical between a pair of dashes (`—aside—`) | parentheses |
| Apposition mid-sentence | colon |
| Trailing / closing clause | comma |
| Two independent clauses joined | period (or semicolon if the thought is one thought) |

## At-scale mechanics (the part that breaks repos)

- **Never sweep paired punctuation with a multiline regex.** A pattern that matches `—text—` and
  turns it into parentheses will cross line boundaries and invent pairs that never existed. In
  markdown this is vicious: two consecutive table rows that each end in an em dash look like one
  open-close pair to a multiline regex, so it merges unrelated rows:

  ```
  | **SUTCETI** | En desarrollo ( demo por presentar |
  | **Uvaviña** | Prospecto ) presentando propuestas |
  ```

  That is corrupted content, and it can hit preexisting text you never meant to touch.
- **Edit line by line, with a single-match assertion.** Replace one occurrence at a time, and
  assert the old string matches exactly once in the file before applying (the way a safe
  find-and-replace refuses an ambiguous match). One dash, one decision, one edit.
- **Verify by RENDERING, not by counting delimiters.** Counting balanced parentheses passes the
  corrupted table above, because the bad edit added one open and one close. Look at the rendered
  markdown / the running UI, not at a delimiter tally. Delimiter counts confirm the bug instead
  of catching it.

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
4. Per file, replace line by line with the map above, honoring the carve-out.
5. Verify by rendering, and grep the working tree excluding carve-out contexts and moved files.
