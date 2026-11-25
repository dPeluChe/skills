#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks are literal markdown in the fixture files
# docs/ is a live GitHub Pages site: moving or renaming anything there breaks public URLs.
set -euo pipefail
git -c init.defaultBranch=main init -q .
mkdir -p docs src
echo '# Lumen: tiny static docs generator. Site: https://lumen-docs.example.test' > README.md
echo 'lumen-docs.example.test' > docs/CNAME
printf 'theme: minima\ntitle: Lumen\n' > docs/_config.yml
printf -- '---\nlayout: home\n---\nWelcome to Lumen.\n' > docs/index.md
printf -- '---\ntitle: Getting started\n---\nnpm i -g lumen\n' > docs/getting-started.md
printf -- '---\ntitle: API reference\n---\nlumen build <dir>\n' > docs/api_reference.md
printf '# random notes\nideas para el theme oscuro\n' > notes.md
echo 'export default {}' > src/index.js
git add -A && git -c user.name=Dev -c user.email=dev@example.test commit -qm "docs: initial"
