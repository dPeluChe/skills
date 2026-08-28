# RESOLVED: the ~1/3 suite flake was a random canary input, not timing

`bash scripts/test-hooks.sh` failed roughly one run in three, landing on a
different test each time (agent-block, hooks_skip, verify-report, panel
breakdown). It lived in `main` for months, was assumed to be "shared state or
timing under bash 3.2", and was never root-caused. It was neither shared state
nor timing.

## Root cause

`canary_panel()` in `scripts/lib/verify.sh` built three of its six synthetic
secrets from `/dev/urandom`. One of them, the generic shape, relied on gitleaks'
`generic-api-key` rule, which **filters findings by STOPWORD**: any secret whose
text contains a common word is dropped as a false positive.

A random 40-character alphanumeric string contains such a word about 1% of the
time. When it did, gitleaks reported nothing, the canary read that as the gate
failing to block, and `verify` closed with FAIL.

The probe was feeding a nondeterministic input to a heuristic rule and then
reading "my input did not match" as "the gate stopped blocking".

## Evidence

| Measurement | Result |
|---|---|
| 500 random draws scanned with the central config | 5 undetected, **1.00%** |
| Entropy of the undetected draws | 4.75 to 5.12, **above** the 3.5 threshold, so not entropy |
| Same base value with `pull`, `line` or `base` spliced in | **UNSEEN**, deterministically; without it, detected |
| Install/verify runs per suite | **40** |
| Predicted suite failure rate | 1 - 0.99^40 = **33%** |
| Observed historical rate | **~1/3**, matches |

"A different test each run" was simply whichever of the 40 installs drew the
unlucky value.

Only the generic shape was affected. `dpat`, `aws` and `sentry-dsn` were already
deterministic and never flaked; `iteris-token` and `postgres-uri` drew random
values too, but their rules are plain regex with no stopword filter, so they
were a latent hazard rather than an active one.

## Impact beyond CI

`verify` runs inside `install.sh --repo` in ANY repo, not only in the suite. So
about 1% of real installs printed a **false security alarm** claiming the central
rules had stopped blocking secrets. That is why the fix belongs in the product
code and not in the tests.

## Fix

- **Deterministic panel.** Every shape is now assembled at runtime from fixed
  fragments (no secret-shaped literal lives in the file, same constraint as
  before). The generic shape was replaced by a strict-format DEFAULT rule
  (`stripe-access-token`): it has no entropy or stopword heuristic, so it is
  caught every time when `[extend] useDefault = true` is on, and missed the
  moment it is turned off. That is exactly the regression the shape exists to
  catch, now without randomness.
  **Coverage this narrows, on purpose:** the entropy-based `generic-api-key`
  detector is no longer exercised at all. Both shapes prove `useDefault = true`
  equally well (one rule out of ~170 either way), so the shape's stated purpose
  is intact, but a repo-local `.gitleaks.toml` that keeps the defaults on while
  neutering the generic detector through its own `[allowlist]` would now show a
  green canary. Restoring that probe would mean feeding a heuristic rule again,
  which is the practice this whole document argues against.
- **Regression guard** (`scripts/tests/90-gitleaks-scope.sh`): asserts the panel
  is a **pure function** (two calls byte-identical, so re-introducing a random
  draw fails loudly instead of flaking), that it still emits 6 shapes, that every
  shape is detectable by the central config, and that `default-ruleset` is the one
  and only shape that goes UNSEEN with `useDefault = false`.
- **Failure diagnosability.** The suite itself now keeps its fixtures when it
  FAILS and wipes them when it passes (`scripts/tests/00-helpers.sh`), so local
  runs are self-diagnosing too, and the `gate` job uploads them as an artifact on
  failure. Both CI jobs share one collector (`scripts/collect-fixture-logs.sh`,
  linted by the suite like any other script) so the file filter cannot drift
  between them. Previously only the manual `diagnose` job collected anything, so
  an intermittent red gate carried no evidence and had to be re-derived by hand.
  That missing feedback loop is the reason this survived so long.
- **Named assertion** (`scripts/tests/70-field-feedback.sh`): the verify-report
  check now says which line was missing and echoes the verify verdict lines,
  so the console alone shows the cause.

## Deferred: telling probe rot from a gate failure

Determinism fixes the probe's input, not its environment. The shapes still depend
on whatever gitleaks the user has installed, so the day a bundled rule is renamed
or dropped, `verify` would blame the gate. A first attempt at this (re-scanning an
UNSEEN shape against the reference ruleset, and reporting rot instead of failure
when it is undetectable there too) passed locally 10 out of 10 but made CI report
PASS on the `drop-rule` fixture, which must FAIL. Since that direction can suppress
a REAL "the gate stopped blocking" verdict, it was removed rather than left in on a
hunch. It is worth re-landing only with a reproduction and a CI-proven guard.

## Rule this leaves behind

A probe must never feed a random input to a rule that filters heuristically.
If a check's own input can vary, its failures cannot be told apart from the
failures it exists to detect. Retrying such a check would have been worse than
the flake: the "secret not blocked" signal is identical for a bad draw and for a
real security regression, so a retry would have masked real ones.
