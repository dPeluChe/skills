# `.doctos.yml`: the declared structure

Loaded from SKILL.md when a repo has `.doctos.yml`, or when INIT or CLEAN writes one.

Shapes this lets a repo keep without renaming everything: ADRs, Diataxis, a team convention in
lowercase, a docs folder that is not `docs/`.

```yaml
docs_root: docs                 # where documentation lives
naming: UPPERCASE_SNAKE         # or kebab-case, or lowercase
folders:                        # folder: what belongs in it
  ARCHITECTURE: architecture, schemas, decisions, technical trade-offs
  GUIDES: setup, deploy, onboarding, conventions
  ARCHIVED: obsolete docs, each with an archival note
root_allowed: [CONTRIBUTING.md] # extra .md tolerated at the repo root
```

**The descriptions are not decoration: they are the routing table.** Classifying a stray file
means matching its content against what each folder is for, so a declared taxonomy works with
the existing logic and needs no special case.

**Why the root and not `docs/`.** The file says WHERE documentation lives, so it cannot live
inside it: a repo with `documentation/` or `website/docs/` would need doctos to guess the
location of the file that tells it the location. At the root it sits with the other tooling
config (`.gitignore`, `lefthook.yml`), it is found in one look, and it is **committed, never
gitignored**: the structure has to travel with the clone and a change to it has to show up in a
PR like any other decision.

**Verify it, do not obey it.** A config that lies is worse than none, because it makes a mess
look sanctioned. Before using a declared structure, check it against reality and report the
drift as findings: folders declared that do not exist, folders that exist and are not declared,
a `docs_root` that is absent. Then audit against the declaration.

**`docs/README.md` stays the human door, and it is DERIVED.** Its structure table is generated
from this file and carries a line saying so, because the same list kept by hand in two places
drifts and then nobody knows which one is true. When the two disagree, `.doctos.yml` wins and
the difference is a finding.

**The project README announces it.** A contributor who opens the repo has no reason to guess
that documentation follows a convention or where it is written down, and a config nobody can
find gets edited around instead of edited. INIT adds one short block to the root `README.md`,
and AUDIT reports its absence as a finding:

```markdown
## Documentation

Structure declared in [`.doctos.yml`](./.doctos.yml), index in [docs/README.md](./docs/README.md).
```

Two lines, no more: the README is an overview, not a manual. This is a pointer, never a copy of
the structure, for the same reason the `docs/README.md` table is derived.

**The default is measured, not invented.** A survey of 134 repos with a `docs/` folder found the
canonical set in real use: TASK_COMPLETED (52), ARCHITECTURE (46), GUIDES (43), RESEARCH (34),
ARCHIVED (26), FEATURES (25), JOURNAL (20). That is why doctos stays opinionated by default. The
same survey is why the declaration exists: a folder for a product or integration recurred in 6
repos with no slot in the taxonomy, and two code repos run a fully Spanish one
(`DOMINIO/PRODUCTO/OPERACION`). Neither is a mess to be renamed; both are structures to be
declared.

**Precedence.** The published-site guard still wins over everything (moves break live URLs). A
declaration beats the content-repo heuristic, since it is explicit where the heuristic guesses.
The default applies only when there is no file. `/doctos init` writes the file with the default
values, and CLEAN offers to add it when it is missing, always as one more confirmed line in the
plan, never silently.
