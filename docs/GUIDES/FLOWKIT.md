# flowkit: the CLI

> Moved out of the README: it is reference, not a landing page. Install and first steps live in the [README](../../README.md); everything the CLI can do lives here.

### flowkit (recommended)

`flowkit` is the CLI for this repo, a generic manager for the skills + hooks + flow
layer. Install once and every operation (sync, doctor, hook wiring, upgrades) is one
command from any directory: `make install` links the skills chain AND drops a
`flowkit` symlink into `~/bin` (it warns with the exact `~/.zshrc` line if `~/bin`
is not in your PATH).

```bash
git clone https://github.com/dPeluChe/skills.git
cd skills && make install   # skills chain + ~/bin/flowkit

# from then on, from ANY directory:
flowkit help       # subcommands, one line each
flowkit install    # re-sync skills after a git pull
flowkit check      # doctor: validate every link without touching anything (exit 0/1)
flowkit prune      # sync + remove dead links left by renamed/deleted skills
flowkit hooks      # wire centralized git hooks into the repo you're standing in
flowkit hooks --verify   # check the EFFECTIVE hook state: config + hooksPath + merged jobs
                         # + gitleaks config in use + canary secret probe, exit 0/1
flowkit unhook     # clean removal from the current repo: stubs, OUR configs, OUR exclude entries
flowkit upgrade    # lefthook/gitleaks versions + clone freshness (exit 1 if pending);
                   # inside a wired repo it also refreshes that repo's lefthook remotes cache
flowkit about      # what flowkit is + this repo's detected flow status (for agents landing cold)
flowkit version    # flowkit 0.1.4 (<short sha>), also --version / -v
```

`flowkit hooks` accepts `--team` and `--include-parent`: same semantics as the
installer (see [HOOKS.md](./HOOKS.md)). The CLI is pure dispatch:
all logic lives in `scripts/install.sh`, so the alternatives below stay equivalent.

Versioning: the root `VERSION` file follows a `0.1.x` scheme, bumped manually per PR
that touches the tooling, PRs touching `bin/` `scripts/` `hooks/` bump VERSION patch.

### Claude Code (plugin)

```bash
/plugin marketplace add dPeluChe/skills
/plugin install doctos@dpeluche-skills
```

### Manual (make / scripts, alternative)

```bash
cd skills && ./scripts/install.sh          # links all skills (chain: ~/.claude/skills → ~/.agents/skills → repo)
./scripts/install.sh ship                  # or just one
./scripts/install.sh --check               # doctor: validate every link without touching anything (exit 0/1)
./scripts/install.sh --prune               # also remove dead links left by renamed/deleted skills
./scripts/install.sh --copy doctos         # copy instead of link (editable, frozen)
```

The chain goes through `~/.agents/skills` as a shared hub so other agent harnesses
can serve the same skills; the script creates both hops and is idempotent, run it
(or `flowkit install`) after every `git pull` that adds skills. `--check` also
validates the `~/bin/flowkit` link.

The `Makefile` wraps the same flows, `make help` lists them:

```bash
make install    # ./scripts/install.sh (also links ~/bin/flowkit)
make check      # ./scripts/install.sh --check
make prune      # ./scripts/install.sh --prune
make upgrade    # ./scripts/install.sh --upgrade
make harness    # ./scripts/install.sh --harness (Claude Code PreToolUse guards)
make test       # bash scripts/test-hooks.sh
```

