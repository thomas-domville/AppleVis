#!/usr/bin/env bash
set -euo pipefail

# Produces a clean source-only ZIP for handoff — excludes dependencies,
# local tooling state, and generated caches that bloat the archive and
# should never be shipped (see README packaging note).

OUT="AppleVis-clean-$(date +%Y%m%d-%H%M).zip"

zip -r "$OUT" . \
  -x "node_modules/*" \
  -x ".git/*" \
  -x ".expo/*" \
  -x ".claude/*" \
  -x "Temp/*" \
  -x "ios/*" \
  -x "android/*" \
  -x "dist/*" \
  -x "web-build/*" \
  -x "*.log" \
  -x "*.tmp"

echo "Created $OUT"
