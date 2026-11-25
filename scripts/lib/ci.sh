# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (note, agent_action, ...) come from util.sh
# ── ci: stamp the caller of the reusable flowkit-gate workflow (opt-in: it is a
#    committed file and spends CI minutes, so `flowkit hooks` never does it) ──

ci_setup_cmd() { # $1 = target repo; toolchain install the lint/typecheck need
  local t="$1"
  if   [[ -f "$t/pnpm-lock.yaml" ]]; then echo "corepack enable && pnpm install --frozen-lockfile"
  elif [[ -f "$t/yarn.lock" ]];      then echo "corepack enable && yarn install --immutable"
  elif [[ -f "$t/package-lock.json" ]]; then echo "npm ci"
  elif [[ -f "$t/package.json" ]];   then echo "npm install"
  fi
}

run_ci_stamp() { # $1 = target repo
  local target="$1" wf="$1/.github/workflows/flowkit-gate.yml" setup
  git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || { bad "not a git repo: $target"; return 1; }
  if [[ -f "$wf" ]]; then
    note "-> $(basename "$wf") already exists -- left as is"
    return 0
  fi
  setup="$(ci_setup_cmd "$target")"
  local with="secrets-only: true # no toolchain detected; set setup: to also run lint/typecheck"
  [[ -n "$setup" ]] && with="setup: $setup"
  mkdir -p "$(dirname "$wf")"
  cat > "$wf" <<EOF
name: flowkit gate

# CI backstop for pushes made with git hooks off (Claude Code /ship watch,
# GUI clients). Same gates as the hooks: dPeluChe/skills scripts/gate.sh.
on:
  pull_request:

jobs:
  gate:
    uses: dPeluChe/skills/.github/workflows/gate.yml@main
    with:
      $with
EOF
  note "-> stamped .github/workflows/flowkit-gate.yml${setup:+ (setup: $setup)}"
  agent_action "Commit .github/workflows/flowkit-gate.yml, then make the 'gate / gate' check required on the default branch (Settings -> Rules) so a red gate cannot merge."
}
