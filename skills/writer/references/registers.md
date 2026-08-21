# Writer — channel registers (load the one that matches the target channel)

Each register overrides the generic rules for its channel only. Load the section that matches
what's being edited; ignore the rest.

## CV / application register

CV slop is its own dialect — add these to the ban list when editing CVs, resumes, or application
answers: results-oriented professional, proven track record, spearheaded, facilitated
cross-functional synergies, demonstrated ability to drive, dynamic self-starter, detail-oriented
team player, "passionate about [field]" as a qualification.

CVs bound for ATS parsers also need ASCII-safe text: em/en dashes → plain hyphens, curly quotes →
straight, no zero-width or non-breaking spaces, no tables, reverse-chronological `Company — Title`
+ date lines, standard section headers (Summary, Experience, Skills, Education). If the project has
a normalize-on-export pipeline the source may keep typography; with no pipeline, normalize the source.

## Business / client comms register (email, proposals, prospect updates)

Agent drafts default to a **"sales email" dialect** — the business-register equivalent of AI slop.
It reads as a vendor template, not as the author. Cut it:

- **No manufactured warmth / ingratiation.** Kill openers like "nos da gusto que...", "great news",
  "excited to share" — a warm compliment the author didn't feel reads as a template.
- **No urgency / deadline CTA.** Kill "¿avanzan antes del [fecha]?", "act now so we can…", any
  pressure-to-decide close. State the relevant fact plainly ("the charge recurs each month") and let
  the reader decide — don't push.
- **Flip the next step toward help.** The next step is what the SENDER will do to help ("we'll
  analyze the charges and share the amount"), NOT what the receiver must decide. Help flows outward;
  pressure never flows inward.
- **Show the real artifact.** Link to what was actually built ("the proposal: <url>"), don't just
  describe it. Builder shows work, doesn't narrate it.
- **Plain prose, no section bold.** Client emails are read as prose, not scanned as a deck. Reserve
  emphasis; and explain a choice when you make one ("we thought email, but put it on a page so it
  reads without clutter").

This is the portfolio voice ("honest, not aspirational") extended to business: an honest peer
sharing findings and offering help, never a vendor closing a deal.

## STE register (opt-in, never default)

Only when the user asks for it ("reporta en STE", "in STE", "Simplified Technical English"), apply
ASD-STE100-style rules for technical reports/procedures: sentences of 20 words or less (25 for
description), one instruction per sentence, active voice, simple tenses, one meaning per word,
plain everyday vocabulary. Voice-pack rules do not apply in this register — STE is deliberately
voiceless. Never use it for social posts, essays, or anything where voice matters.

## Claims and evidence (docs, product copy, applications)

- Every strong claim answers: what actually happened · how do I say it without inflating · what
  evidence backs it. If the author has no source, ask — never invent one.
- Metrics stay concrete and live where they belong; a piece shouldn't need many metrics to be credible.
- No formulaic "Despite challenges... Future outlook..." sections. No "committed to excellence" filler.
- LLM failure mode to reverse: regression to the mean makes text **less specific and more exaggerated
  at once**. The fix is always the specific fact.

**Evidence-bound mode (anti-laundering).** When the input is vague copy — "faster decisions", "better
alignment", "reduced friction", "seamless integration" — do NOT polish it into cleaner vague copy.
That launders emptiness into something that *sounds* backed. Convert each unbacked phrase into either
a **proof gap** (mark it: "needs a number / a source") or a **question to the author** ("faster than
what — do we have the before/after?"). Never invent the feature, date, or metric that would fill it.
