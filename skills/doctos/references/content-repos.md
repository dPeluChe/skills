# Content repos: when the documents are the product

Loaded from SKILL.md when the repo-type check finds a content repo.

The layout and naming rules in SKILL.md assume `.md` files are documentation ABOUT a system. Here the documents ARE the product (a bylaw, contracts, a corpus, a book): moving a content file into `docs/GUIDES/` is like moving `src/` into `docs/`. Detection runs in SKILL.md (Repo type) before this file loads.

**In a content repo, the default layout does not apply. Instead:**
- **Do not move the content into `docs/`.** `docs/` holds only META about the repo (how the material is organized, how to contribute, a changelog). The content itself lives organized **by domain**: by area, topic, or the material's own structure, never folded into the technical taxonomy.
- **The technical taxonomy has no slot for content.** ARCHITECTURE / FEATURES / GUIDES / RESEARCH all describe documentation about a system; a bylaw or a contract fits none of them. Do not force content into them. Use domain folders that fit the material and that a reader of that material would expect.
- **Match the audience's language and literacy in folder names.** These repos get opened by non-technical readers (neighbors, older people, clients), often in Spanish. `archivo/` is understood; `ARCHIVED/` is not. Use readable, localized names (`archivo/`, `guias/`, `borradores/`), not UPPERCASE English. The UPPERCASE English convention in SKILL.md is for technical / code repos.

This is the same spirit as the published-site guard and the "respect documented conventions" rule: when a repo has its own working structure, doctos reports hygiene findings but never imposes the default layout on top of it.
