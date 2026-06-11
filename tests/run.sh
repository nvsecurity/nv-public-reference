#!/usr/bin/env bash
# Shared lint entrypoint for nv-public-reference. CI (.github/workflows/lint.yml)
# invokes this exact script, so a local run and a CI run can never check different
# things or drift apart over time.
#
# What it checks, for every tracked shell script:
#   1. bash -n     - syntax / parse check
#   2. shellcheck  - static analysis (quoting, set -e pitfalls, unsafe expansions)
#
# Usage: tests/run.sh
set -euo pipefail

# Run from the repository root regardless of the caller's working directory, so the
# git file list and relative paths resolve identically in local and CI runs.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# The shellcheck tool is required, not optional: silently skipping it when absent
# would let a local run pass on a weaker check than CI, which is the exact drift
# this shared entrypoint exists to prevent.
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "ERROR: shellcheck not found on PATH. Install it and re-run:" >&2
    echo "  macOS:  brew install shellcheck" >&2
    echo "  Debian: sudo apt-get install -y shellcheck" >&2
    echo "  other:  https://github.com/koalaman/shellcheck#installing" >&2
    exit 1
fi

# Enumerate tracked shell scripts via git so untracked / vendored files (for example
# the .agent-sandbox-config tree) are never linted. A read loop (rather than mapfile)
# keeps this working on bash 3.2, the default on macOS, so local runs match CI.
scripts=()
while IFS= read -r script_path; do
    scripts+=("$script_path")
done < <(git ls-files '*.sh')
if [ "${#scripts[@]}" -eq 0 ]; then
    echo "No tracked *.sh files found; nothing to lint."
    exit 0
fi

echo "Linting ${#scripts[@]} shell script(s):"
printf '  %s\n' "${scripts[@]}"

# Cheap parse check first; set -e aborts on the first failure so CI fails the job.
for script in "${scripts[@]}"; do
    bash -n "$script"
done

# Then the deeper static analysis pass over the whole set in one invocation.
shellcheck "${scripts[@]}"

echo "OK: all shell scripts passed bash -n and shellcheck."
