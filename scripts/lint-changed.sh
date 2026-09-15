#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_REF="${BASE_REF:-main}"
STYLE_CONFIG_DIR="${AGENT_CONFIG_HOME:-${HOME}/.agents}/skills/swift-conventions/config"

command -v swiftlint >/dev/null 2>&1 || { echo "error: swiftlint is required" >&2; exit 1; }

files=()
while IFS= read -r path; do
    [[ -f "$ROOT_DIR/$path" ]] && files+=("$ROOT_DIR/$path")
done < <(
    git -C "$ROOT_DIR" diff --name-only "$BASE_REF"...HEAD -- '*.swift'
    git -C "$ROOT_DIR" diff --name-only -- '*.swift'
    git -C "$ROOT_DIR" diff --cached --name-only -- '*.swift'
)

if [[ ${#files[@]} -eq 0 ]]; then
    echo "swiftlint: no changed Swift files"
    exit 0
fi

SWIFTLINT_ARGS=(lint --strict --config "${STYLE_CONFIG_DIR}/.swiftlint.yml")
if [[ -f "$ROOT_DIR/.swiftlint-baseline.json" ]]; then
    SWIFTLINT_ARGS+=(--baseline "$ROOT_DIR/.swiftlint-baseline.json")
fi
swiftlint "${SWIFTLINT_ARGS[@]}" "${files[@]}"
