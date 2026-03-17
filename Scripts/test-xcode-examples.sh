#!/bin/bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

log "Checking required executables..."
XCODEBUILD_BIN=${XCODEBUILD_BIN:-$(command -v xcodebuild || xcrun -f swift)} || fatal "XCODEBUILD_BIN unset and no xcodebuild on PATH"

CURRENT_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(git -C "${CURRENT_SCRIPT_DIR}" rev-parse --show-toplevel)"
TMP_DIR=$(/usr/bin/mktemp -d -p "${TMPDIR-/tmp}" "$(basename "$0").XXXXXXXXXX")

PACKAGE_PATH=${PACKAGE_PATH:-${REPO_ROOT}}
EXAMPLES_PACKAGE_PATH="${PACKAGE_PATH}/Examples"
SHARED_EXAMPLE_HARNESS_PACKAGE_PATH="${TMP_DIR}/example-harness"
SHARED_PACKAGE_SCRATCH_PATH="${TMP_DIR}/example-scratch"
SHARED_PACKAGE_CACHE_PATH="${TMP_DIR}/example-cache"
XCODEBUILD_DESTINATION=${XCODEBUILD_DESTINATION:-"generic/platform=macOS"}
ORIGINAL_LOCAL_DEPENDENCY_PATH=${ORIGINAL_LOCAL_DEPENDENCY_PATH:-"../../../swift-configuration"}

for EXAMPLE_PACKAGE_PATH in $(find "${EXAMPLES_PACKAGE_PATH}" -maxdepth 2 -name '*.xcodeproj' -type d -print0 | xargs -0 dirname | sort); do

    EXAMPLE_PACKAGE_NAME="$(basename "${EXAMPLE_PACKAGE_PATH}")"

    if [[ "${SINGLE_EXAMPLE_PACKAGE:-${EXAMPLE_PACKAGE_NAME}}" != "${EXAMPLE_PACKAGE_NAME}" ]]; then
        log "Skipping example: ${EXAMPLE_PACKAGE_NAME}"
        continue
    fi

    log "Recreating shared example harness directory: ${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"
    rm -rf "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"
    mkdir -v "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"

    log "Copying example contents from ${EXAMPLE_PACKAGE_NAME} to ${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"
    git archive HEAD "${EXAMPLE_PACKAGE_PATH}" --format tar | tar -C "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}" -xvf- --strip-components 2

    # GNU tar has --touch, but BSD tar does not, so we'll use touch directly.
    log "Updating mtime of example contents..."
    find "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}" -print0 | xargs -0 -n1 touch -m

    log "Building example app: ${EXAMPLE_PACKAGE_NAME}"
    ( 
        cd "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"

        # There is no CLI to modify dependencies, revert to sed
        PBXPROJ=$(find . -name "project.pbxproj" -type f -maxdepth 2)
        sed -i '' "s|${ORIGINAL_LOCAL_DEPENDENCY_PATH}|${PACKAGE_PATH}|g" "$PBXPROJ"

        "${XCODEBUILD_BIN}" build \
            -scheme "${EXAMPLE_PACKAGE_NAME}" \
            -destination "${XCODEBUILD_DESTINATION}" \
            -clonedSourcePackagesDirPath "${SHARED_PACKAGE_CACHE_PATH}" \
            -skipPackageUpdates \
            -derivedDataPath "${SHARED_PACKAGE_SCRATCH_PATH}"
        log "✅ Successfully built the example app ${EXAMPLE_PACKAGE_NAME}."
    )
done
