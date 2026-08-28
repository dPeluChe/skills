# RESOLVED (0.1.17): canary/verify test flake

Was: `bash scripts/test-hooks.sh` intermittently failed (~1 in 6, then
consistently under github rate-limiting) in the verify/canary family.

## Root cause

The fixtures wired lefthook `remotes` at the real `https://github.com/dPeluChe/skills`.
The canary/verify tests run the EFFECTIVE hook, which made lefthook `git clone`
that public repo -- ~20 suite runs a day × many fixtures = hundreds of anonymous
clones → github rate-limited the IP, turning the flake into consistent failure.

## Why the first local-remote attempt broke upgrade/0-jobs

`lefthook_cfg_file` (verify.sh) only treats a config as "wired" if it
`grep`s `$REMOTE_URL`. Two fixtures (FFUPG, GSINERT) HARDCODED the github URL,
so pointing `REMOTE_URL` at a local path stopped matching them → those two
tests failed. That looked like "local remotes don't work" but was just the
hardcoded refs.

## Fix

- `00-helpers.sh` builds a minimal local remote (only `hooks/lefthook-base.yml`
  + `hooks/.gitleaks.toml`, committed on main) and exports `REMOTE_URL` to it.
- `util.sh` makes `REMOTE_URL` env-overridable (`${REMOTE_URL:-…}`).
- FFUPG and GSINERT fixtures now reference `$REMOTE_URL`, not a hardcoded URL.

Result: the suite never touches github; 153/153 deterministic across runs. The
one remaining github call is `run_upgrade`'s `git fetch origin` on the real
skills clone (once per suite run) -- real behavior, not enough to rate-limit.

---

## Not the same as the ~1/3 flake

A second, unrelated flake survived this one: `canary_panel` drew RANDOM values,
and gitleaks' stopword filter dropped ~1% of them, which the canary reported as
a security regression. Root cause, evidence and fix: `CANARY_DETERMINISM.md`.
