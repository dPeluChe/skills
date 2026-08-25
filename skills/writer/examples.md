# Writer examples, before/after gallery and detect fixtures (English)

Grows with real use: when an edit lands well (or a piece gets a strong response), compare the
skill's output with the final published version, extract ONE reusable before/after, review it,
and append it here. Over time the gallery converges on the author's actual voice. All sample text
below is invented, no third-party prose. The Spanish gallery and fixture live in
`references/spanish.md`.

## Before/after by pattern

**Binary contrast**
- before: "The question isn't the model. It's the eval." after: "The eval matters more than the model."

**Colon reveal**
- before: "The best part: it learns from every edit." after: "It learns from every edit."

**Throat-clearing**
- before: "Here's the thing: shipping beats planning." after: "Shipping beats planning."

**Superficial analysis (dangling gerund)**
- before: "The release adds file search, highlighting the team's commitment to better workflows." after: "The release adds file search, so users can find old drafts without leaving the editor."

**Importance puffery**
- before: "The launch marks a pivotal moment for the company." after: "The launch is the company's first paid product."

**Weasel attribution**
- before: "Experts agree small teams ship faster." after: "Our last three projects shipped in under six weeks with a team of two."

**Fake-strong verbs**
- before: "The app serves as a centralized hub for sponsor management." after: "The app tracks sponsors, drafts, due dates, and approvals in one place."

**Protect the specific fact**
- before: "The tool significantly improves engineering productivity." after: "The tool cut review time from 30 minutes to 8."

**Fake-profound kicker**
- before (ending): "...and that's the real magic: code, like rivers, always finds its way." after: delete; end on the previous concrete sentence.

**Forced-optimism ending / moral lesson**
- before (ending): "The road ahead is challenging, but the future looks bright. If there's one lesson here, it's that persistence pays." after: delete both; end on the last shipped fact.

**Hedge stack**
- before: "This could potentially perhaps lead to somewhat better results." after: "This may improve results." (or commit: "This improves results by X.")

## Detect fixture, English

Paste into detect mode; expect exactly these six findings.

> Here's the thing: our new dashboard isn't just a reporting tool. It's a paradigm shift. It serves as a centralized hub for every metric that matters, streamlining workflows and highlighting our commitment to data-driven culture. Experts agree that visibility is the foundation of velocity. The best part: it configures itself. Fast. Simple. Powerful. That's it. That's the whole story.

Expected findings: throat-clearing opener ("Here's the thing"), binary contrast ("isn't just... It's..."), banned words plus fake-strong verb ("paradigm shift", "serves as", "streamlining"), superficial analysis ("highlighting our commitment"), weasel attribution ("Experts agree"), colon reveal plus dramatic fragmentation ("The best part:...", "Fast. Simple. Powerful. That's it.").

## False-positive fixtures, must come back CLEAN

Paste into detect mode; the correct output is **"reads clean"** (or only the single true tell
noted), NOT a list of findings. These guard the clusters rule against an over-eager detector.

**Plain technical prose (0 findings)**
> The parser reads the lockfile, resolves each dependency to a single version, and writes the
> result to `node_modules`; if two packages need incompatible versions, it nests the second copy.
- Correct verdict: clean. In-domain verbs and a semicolon are not slop. No cluster.

**Blunt human post (0 findings)**
> I shipped it Friday and it broke by Monday. Turns out nobody tested the offline path. My fault.
> Fixed now, and I added the test I should have written first.
- Correct verdict: clean. A strong admission and uneven rhythm are signs of a human, not tells. (Note: an em dash here WOULD be a finding, even in an otherwise human post; this example uses none.)

**Spanglish standup (0 findings)**
> Terminé el refactor del hook, pero el CI todavía falla en el gitleaks step. Mañana lo debuggeo
> con calma; creo que es el baseline viejo.
- Correct verdict: clean. Mixed language IS the voice; "creo que" carries real uncertainty.

**Terse changelog (0 findings)**
> Fixed the crash on empty input. Bumped the timeout to 30s. Removed the dead retry loop.
- Correct verdict: clean. Short and factual is not "dramatic fragmentation"; there is no punchy climax.

**Deliberately neutral reference (0 findings)**
> This function returns `null` when the key is absent. Callers must check the return value before use.
- Correct verdict: clean. Sterile is the correct human voice in reference text; the genre gate blocks a flatness flag.

**One true tell in an otherwise clean piece (exactly 1 finding)**
> The migration script backfills the new column in batches of 500, citeturn0search1 so it never
> locks the table for long.
- Correct verdict: 1 finding, forensic residue (`citeturn0search1`). Report it on sight even though the prose is otherwise clean; do not manufacture extra findings to pad the list.

## At-scale em-dash sweep fixtures (see references/em-dash.md)

Real failure modes from a whole-repo purge. The correct behavior is the note, not a blind conversion.

**Two table rows each ending in an em dash: do NOT merge**
```
| **SUTCETI** | En desarrollo — demo por presentar |
| **Uvaviña** | Prospecto — presentando propuestas |
```
- Correct: fix each row independently (each em dash becomes a comma inside its own cell). A multiline paired-punctuation regex would read the two dashes as one open-close pair and merge the rows into corrupted content. Verify by rendering the table, not by counting delimiters.

**Em dash as a UI glyph in code: do NOT touch**
```tsx
<td>{client.email || "—"}</td>
```
- Correct: leave it. The "—" is the "no data" cell marker the interface renders, not prose. Converting it is a bug. Same for em dashes inside code comments or code fences.

**A born-historical record: skip, do not "correct"**
> `docs/JOURNAL/STANDUP_260725.md`: "Shipped the parser — tests still red on Windows."
- Correct: leave the entry as written. JOURNAL/ and ARCHIVED/ record a moment; editing them (even to remove the em dash) falsifies the record. Detect may note it; edit skips it.

**Source and derived: fix the source first**
> `docs/profile/07-cv.md` holds "Antonio Martinez — CEO & Builder"; `README.md` and `layout.tsx` (browser/OG/Twitter title) quote it.
- Correct: fix `docs/profile/07-cv.md` first (the source), then the derived surfaces, so the tell does not regenerate on the next build. The site title is a bio and the highest-leverage prose in the repo (Google + every share preview), map it first.
