#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PBXPROJ="${PROJECT_ROOT}/Notinhas.xcodeproj/project.pbxproj"

if [[ "${SKIP_DAILY_VERSION_BUMP:-0}" == "1" ]]; then
  exit 0
fi

force_bump="${FORCE_DAILY_VERSION_BUMP:-0}"

if [[ ! -f "${PBXPROJ}" ]]; then
  echo "Daily version bump skipped: missing ${PBXPROJ}" >&2
  exit 0
fi

git_user_email="$(git -C "${PROJECT_ROOT}" config user.email || true)"
if [[ -z "${git_user_email}" ]]; then
  echo "Daily version bump skipped: git user.email is not configured." >&2
  exit 0
fi

if [[ "${force_bump}" != "1" ]] && \
  git -C "${PROJECT_ROOT}" log --all --author="${git_user_email}" \
    --since="today 00:00:00" --format="%H" -n 1 | grep -q .; then
  exit 0
fi

read_setting() {
  local key="$1"
  awk -v key="${key}" '
    $0 ~ "^[[:space:]]*" key " =" {
      value = $0
      sub(/.*= /, "", value)
      sub(/;.*/, "", value)
      gsub(/[ "]/, "", value)
      print value
      exit
    }
  ' "${PBXPROJ}"
}

current_version="$(read_setting MARKETING_VERSION)"
current_build="$(read_setting CURRENT_PROJECT_VERSION)"

major="${current_version%%.*}"
if [[ ! "${major}" =~ ^[0-9]+$ ]]; then
  echo "Daily version bump skipped: invalid current version '${current_version}'." >&2
  exit 0
fi

month="$((10#$(date +%m)))"
day="$((10#$(date +%d)))"
target_version="${major}.${month}.${day}"

if [[ "${current_version}" == "${target_version}" && "${force_bump}" != "1" ]]; then
  exit 0
fi

if [[ ! "${current_build}" =~ ^[0-9]+$ ]]; then
  echo "Daily version bump skipped: invalid build '${current_build}'." >&2
  exit 0
fi

if ! git -C "${PROJECT_ROOT}" diff --quiet -- "${PBXPROJ}"; then
  echo "Cannot run the daily version bump with unstaged changes in:" >&2
  echo "  ${PBXPROJ}" >&2
  echo "Stage or stash that change, then retry." >&2
  exit 1
fi

next_build="$((current_build + 1))"

temporary_file="$(mktemp "${PBXPROJ}.tmp.XXXXXX")"
if ! awk -v new_version="${target_version}" -v new_build="${next_build}" '
  function clear_lines(    i) {
    for (i = 1; i <= line_count; i++) {
      delete lines[i]
    }
    line_count = 0
  }

  function flush_block(    i, opens, closes) {
    if (is_xc_configuration && is_app_configuration) {
      app_count++
      for (i = 1; i <= line_count; i++) {
        if (lines[i] ~ /^[[:space:]]*MARKETING_VERSION =/) {
          sub(/=.*/, "= \"" new_version "\";", lines[i])
          version_count++
        }
        if (lines[i] ~ /^[[:space:]]*CURRENT_PROJECT_VERSION =/) {
          sub(/=.*/, "= " new_build ";", lines[i])
          build_count++
        }
      }
    }

    for (i = 1; i <= line_count; i++) {
      print lines[i]
    }
    clear_lines()
    in_block = 0
    block_depth = 0
    is_xc_configuration = 0
    is_app_configuration = 0
  }

  /^[[:space:]][[:space:]][A-Za-z0-9]+( \/\*.*\*\/)? = \{$/ {
    if (in_block) {
      flush_block()
    }
    in_block = 1
  }

  {
    if (!in_block) {
      print
      next
    }

    lines[++line_count] = $0
    if ($0 ~ /isa = XCBuildConfiguration;/) {
      is_xc_configuration = 1
    }
    if ($0 ~ /PRODUCT_BUNDLE_IDENTIFIER = com\.mourato\.notinhas(\.debug)?;/) {
      is_app_configuration = 1
    }

    opens = $0
    gsub(/[^\{]/, "", opens)
    closes = $0
    gsub(/[^}]/, "", closes)
    block_depth += length(opens) - length(closes)

    if (block_depth == 0) {
      flush_block()
    }
    next
  }

  END {
    if (in_block) {
      flush_block()
    }
    if (app_count != 4 || version_count != 4 || build_count != 4) {
      printf "Daily version bump stopped: expected 4 app configurations with one version/build each, found %d/%d/%d.\\n", \
        app_count, version_count, build_count > "/dev/stderr"
      exit 1
    }
  }
' "${PBXPROJ}" > "${temporary_file}"; then
  exit 1
fi
mv "${temporary_file}" "${PBXPROJ}"

git -C "${PROJECT_ROOT}" add -- "${PBXPROJ}"
echo "Daily version bump applied: ${target_version} (build ${next_build})"
