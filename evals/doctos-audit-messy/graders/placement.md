---
type: llm
---

PASS if the reply proposes a concrete destination under docs/ for the stray root files (notes.md, setup-guide.md, architecture-v2.md) using named subfolders such as GUIDES or ARCHITECTURE and UPPERCASE_SNAKE file names, keeps README.md and CLAUDE.md at the root, and marks old-plan-2024.md as obsolete or to archive.
FAIL if it only lists the files, keeps lowercase/kebab names, or proposes deleting old-plan-2024.md without archiving.
