#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
make -C "$ROOT_DIR" format-check
make -C "$ROOT_DIR" lint
"$ROOT_DIR/scripts/verify-local.sh" --full --plan-only --strict
