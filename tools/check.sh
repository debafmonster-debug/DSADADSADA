#!/usr/bin/env bash
# Full local verification: build place, static analysis, headless tests.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
echo "== rojo build"
rojo build default.project.json -o build/Vostok9.rbxl
rojo sourcemap default.project.json -o sourcemap.json
echo "== selene"
selene --display-style=quiet src
echo "== luau-lsp analyze (type diagnostics are advisory)"
luau-lsp analyze --sourcemap=sourcemap.json --definitions=types/globalTypes.d.luau --no-strict-dm-types src/ \
  | grep -E "SyntaxError|UnknownGlobal|DuplicateFunction|UnknownRequire" && { echo "blocking diagnostics found"; exit 1; } || true
echo "== lune tests"
fail=0
for t in tests/*.spec.luau; do
  echo "-- $t"
  if ! lune run "$t" | tail -n 1; then fail=1; fi
done
[ "$fail" -eq 0 ] || { echo "tests failed"; exit 1; }
echo "OK"
