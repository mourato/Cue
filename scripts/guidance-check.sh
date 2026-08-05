#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
git -C "$ROOT_DIR" diff --check
rg -n "Swift 6\.2|swiftformat|swiftlint|agent-check" "$ROOT_DIR/AGENTS.md" "$ROOT_DIR/docs/adr/071-swift-6-2-agent-baseline.md" "$ROOT_DIR/.agents/overlays" >/dev/null
