# Known issue: canary/verify test flake (~1 in 6)

Status: diagnosed, NOT fixed. Deliberate deferral — the naive fix broke more.

## Symptom

`bash scripts/test-hooks.sh` intermittently fails 1-3 asserts (~1 run in 6),
always in the verify/canary family, e.g. "install did not close with a real
verify report". Re-running passes. The tool is correct; the TEST is flaky.

## Root cause

The canary in `--verify` runs the EFFECTIVE pre-commit hook, which makes
lefthook fetch its `remotes` config. The test fixtures (`scripts/tests/70-*`)
write a lefthook.yml pointing at the real `https://github.com/dPeluChe/skills`,
so every canary run does a network fetch. A slow/failed fetch → the hook does
not complete → no "verify: PASS" → false FAIL. It is a network dependency in
the test, not a defect in flowkit.

Deeper implication worth weighing: in production, `flowkit hooks --verify`
could likewise report a transient false FAIL if the remote fetch blips during
its canary run. The real fix should also make the canary WARM the remote before
taking its verdict.

## Why the obvious fix was reverted

Pointing `REMOTE_URL` at the local checkout (`$REPO_DIR`) removes the network
but changed clone/refetch behavior enough to break the `upgrade`-refresh and
`0-jobs` overlay tests (150/2 consistently). A whole-repo local remote is the
wrong shape.

## Correct fix (for a focused session)

Build a MINIMAL local bare remote in `$TMP` once (a tiny git repo carrying only
`hooks/lefthook-base.yml` + `hooks/.gitleaks.toml`, committed on `main`), point
the fixtures' `REMOTE_URL` there. Network-free and deterministic, without the
full-repo clone side effects. Make `REMOTE_URL` env-overridable in `util.sh`
(`${REMOTE_URL:-…}`) and export it from `00-helpers.sh`. Verify the upgrade and
0-jobs tests still pass against the minimal remote before trusting green.
