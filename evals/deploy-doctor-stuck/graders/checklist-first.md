---
type: llm
---

PASS if the reply diagnoses before fixing: it names BOTH problems from the evidence (port 3000 already in use / EADDRINUSE, and missing env vars REDIS_URL and STRIPE_KEY compared with .env.example), and proposes a single next step or hypothesis to verify rather than a long list of things to try.
FAIL if it misses either problem, or answers with a generic list of possible fixes.
