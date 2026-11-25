---
type: llm
---

PASS if the reply is a progress update a non-technical client can read: it describes the search feature as an outcome (search API shipped, empty-query bug fixed), separates shipped work from in-progress work (the search box UI is still in progress), and does not pad with the dependency bump as a highlight.
FAIL if it is a list of commits or hashes, or if it presents the unfinished search box as delivered.
