#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_REF="${BASE_REF:-main}"

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

swiftlint lint --config "$ROOT_DIR/.swiftlint.yml" "${files[@]}"
