#!/usr/bin/env bash
set -euo pipefail

echo "=== [TP-SMIRK-001A Verification Gate] ==="

echo "  [1/4] Building dunning-t-digest with -Wall -Wcompat..."
cabal v2-build dunning-t-digest --ghc-options="-Wall -Wcompat"

echo "  [2/4] Running test-suite dunning-t-digest-test..."
cabal v2-test dunning-t-digest-test

echo "  [3/4] Running dunning-t-digest-demo..."
cabal v2-run dunning-t-digest-demo

echo "  [4/4] Running dunning-t-digest-bench..."
cabal v2-run dunning-t-digest-bench

echo "=== [TP-SMIRK-001A Verification Gate PASSED] ==="
