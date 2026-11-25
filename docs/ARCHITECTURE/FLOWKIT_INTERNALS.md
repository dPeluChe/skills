# flowkit internals

Why the code is shaped the way it is. The code keeps one-line pointers here; the history
of how each decision was reached lives in the PRs and `docs/JOURNAL/`.

## Module map

`scripts/install.sh` parses the mode and flags, sources these modules and dispatches.
`bin/flowkit` only maps subcommands to installer flags.

| Module | Owns |
|---|---|
| `lib/util.sh` | output helpers, versions, constants, shared git plumbing |
| `lib/chain.sh` | skills symlink chain (sync / check / prune), FLOW and `~/bin/flowkit` links |
| `lib/repo-wire.sh` | `--repo`: wire the central hooks into a repo or a workspace of repos |
| `lib/stamp.sh` | per-repo stamps: gitleaks baseline, FLOW import, steward file |
| `lib/stamp-shipconfig.sh` | the `## preship config` block: stack detection, template, parsing |
| `lib/verify.sh` | `--verify`: effective hook state plus the canary panel |
| `lib/lifecycle.sh` | `--unhook`, `--about`, `--harness`, `--upgrade` |
| `lib/lint-health*.sh`, `lib/loc-health.sh` | the advisory audits |
| `lib/ci.sh` | `--ci`: stamp the caller of the reusable gate workflow |
| `.lefthook/<hook>/*.sh` | the hook jobs, served to consumers from the remote clone |
| `.lefthook/lib/common.sh` | the one preship-config parser and gitleaks-config lookup (hooks and `scripts/gate.sh`) |

Skills chain: `~/.claude/skills/<name> -> ~/.agents/skills/<name> -> <repo>/skills/<name>`.

## Canary panel (verify)

- **A panel, not one shape.** A repo-local `.gitleaks.toml` that keeps
  `[extend] useDefault = true` but drops a central custom rule still blocks an AWS key (a
  default rule) while it silently stopped catching the dropped shape. One shape per central
  custom rule, plus one default-ruleset shape that proves `useDefault` is still on.
- **The github-pat rule has no shape.** A `ghp_` value also matches gitleaks' own default
  rule, so it cannot tell the custom rule from the default one.
- **Fragments, never literals.** This repo scans its own source; a secret-shaped literal would
  be blocked by the gate the panel probes.
- **Deterministic values.** Random draws hit gitleaks' generic-api-key stopword filter about 1%
  of the time and read as a regression (`docs/FEATURES/CANARY_DETERMINISM.md`). The postgres
  host avoids `example` / `placeholder`, which are allowlisted.
- **Judged by the real hook.** Each shape is staged in its own temp index (`GIT_INDEX_FILE`)
  and the verdict comes from the pre-commit hook git would run (local hooksPath, then global,
  then `.git/hooks`), never from a direct scanner call. The user's index is never touched.
- **Warm-up run.** The first run fetches the remotes cache and can execute just-fetched jobs
  even when the steady-state merge is empty, so one throwaway run comes first.

## Hook wiring

- **Displaced hooks are surfaced, not chained.** `lefthook install` moves a pre-existing
  `.git/hooks/<hook>` to `<hook>.old` and never runs it. Appending the old hook to the stub
  would make its exit code final, so an `exit 0` hook would let a blocked secret through.
  verify fails until the repo resolves it.
- **Local hooksPath pin.** lefthook 2.x reads a global `core.hooksPath` directly, installs
  there, clobbers the chain wrappers and never writes the checksum, so every run retries the
  sync and reprints a ~30-line warning. A local pin beats the global one.
- **husky.** git runs `.husky/_/<hook>`, a stub that sources `h`, which runs `.husky/<hook>`,
  where flowkit's delegation line lives. verify follows that one level; reading only the stub
  reported a working gate as inactive.

## lint-health

- **Text grep proposes, eslint decides.** A text read finds `"rule": "off"` anywhere but cannot
  tell repo-wide from a scoped `files:` override, so `eslint --print-config` on one real source
  file (not a test or migration) is authoritative.
- **`--measure`** forces a rule on and counts findings, mutating nothing. Under flat config the
  CLI `--rule` flag silently skips plugin rules (a false 0), so a temp config extends the repo's
  config by absolute path. Any failure is reported as inconclusive, never as 0.
- **`--canary`**, four traps:
  1. run the repo's own lint command, never a synthetic eslint call;
  2. plant one violation per extension present, next to a real file of that extension;
  3. call it blind only when a rule that would catch it is actually on;
  4. a parse error is its own finding, not proof the lint ran. This is the common failure:
     a dependency bump unscopes a preset, clobbers a parser and the output is full of parse
     errors, which a naive canary reads as "the linter ran".
