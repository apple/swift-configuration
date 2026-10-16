#!/bin/bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

log "Checking required executables..."
SWIFT_BIN=${SWIFT_BIN:-$(command -v swift || xcrun -f swift)} || fatal "SWIFT_BIN unset and no swift on PATH"
JQ_BIN=${JQ_BIN:-$(command -v jq)} || fatal "jq not found on PATH"

CURRENT_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(git -C "${CURRENT_SCRIPT_DIR}" rev-parse --show-toplevel)"

PACKAGE_PATH=${PACKAGE_PATH:-${REPO_ROOT}}

# Package.swift switches its default traits to all traits when ENABLE_ALL_TRAITS
# is set (used by other CI jobs), which would mask the trait flags passed below.
unset ENABLE_ALL_TRAITS || :

run_tests() {
    local name="$1"; shift
    log "Running tests with trait combination: ${name}"
    "${SWIFT_BIN}" test --package-path "${PACKAGE_PATH}" "$@"
    log "✅ Passed the tests with trait combination: ${name}"
}

run_tests "no traits" --disable-default-traits
run_tests "default traits"
run_tests "all traits" --enable-all-traits

# Derive the trait list from the package manifest so newly added traits are
# covered automatically. The implicit "default" trait is excluded; it is
# covered by the "default traits" run above.
# Note: Reloading enables Logging (declared in Package.swift), so its run
# covers both.
log "Reading trait list from the package manifest..."
PACKAGE_JSON="$("${SWIFT_BIN}" package --package-path "${PACKAGE_PATH}" dump-package)" \
    || fatal "Failed to dump the package manifest"
TRAITS=()
while IFS= read -r TRAIT; do
    TRAITS+=("${TRAIT}")
done < <("${JQ_BIN}" -r '[.traits[] | select(.name != "default") | .name] | sort[]' <<<"${PACKAGE_JSON}")
[[ ${#TRAITS[@]} -gt 0 ]] || fatal "No traits found in the package manifest"

for TRAIT in "${TRAITS[@]}"; do
    run_tests "only ${TRAIT}" --disable-default-traits --traits "${TRAIT}"
done
