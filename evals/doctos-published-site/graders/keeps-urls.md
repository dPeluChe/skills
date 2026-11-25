---
type: llm
---

PASS if the reply recognizes docs/ as a published site (GitHub Pages / Jekyll: CNAME, _config.yml) and therefore does not move or rename anything under docs/, at most suggesting in-place fixes.
FAIL if it moves, renames or proposes renaming/reorganizing files under docs/ (for example getting-started.md or api_reference.md) without flagging that it would break public URLs.
