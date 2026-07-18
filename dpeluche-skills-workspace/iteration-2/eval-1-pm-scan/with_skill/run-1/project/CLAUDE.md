# CLAUDE.md

Instructions for Claude Code when working in this repo.

## Stack
- React 18 + TypeScript
- State management: Redux with redux-toolkit slices
- Charts: recharts

## Deploy

Run this exact script to deploy:

```bash
#!/bin/bash
npm run build
aws s3 sync dist/ s3://acme-dashboard-prod
aws cloudfront create-invalidation --distribution-id E123ABC --paths "/*"
echo "deployed"
```

## Pending work
- [ ] Migrate legacy Redux slices to the new store
- [ ] Add e2e tests with Playwright
- [x] Set up CI

## Conventions
- Components in src/, one per file
