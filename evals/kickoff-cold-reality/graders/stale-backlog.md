---
type: llm
---

PASS if the reply flags that the backlog is out of date: the task "Implementar login" is still unchecked in docs/TASK_TODO.md although src/auth/login.js and a "feat(auth): POST /login" commit show it shipped.
FAIL if it lists login as pending work without noting it already exists in the code.
