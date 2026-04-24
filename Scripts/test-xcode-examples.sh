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
SHARED_DERIVED_DATA_PATH="${TMP_DIR}/example-derived-data"
SHARED_PACKAGE_CACHE_PATH="${TMP_DIR}/example-cache"
SHARED_CLONED_SOURCES_PATH="${TMP_DIR}/example-cloned-sources"
XCODEBUILD_DESTINATION=${XCODEBUILD_DESTINATION:-"generic/platform=macOS"}
ORIGINAL_LOCAL_DEPENDENCY_PATH=${ORIGINAL_LOCAL_DEPENDENCY_PATH:-"../../../swift-configuration"}

for EXAMPLE_PACKAGE_PATH in $(find "${EXAMPLES_PACKAGE_PATH}" -maxdepth 2 -name '*.xcodeproj' -type d -print0 | xargs -0 dirname | sort); do

    EXAMPLE_PACKAGE_NAME="$(basename "${EXAMPLE_PACKAGE_PATH}")"

    if [[ "${SINGLE_EXAMPLE_PACKAGE:-${EXAMPLE_PACKAGE_NAME}}" != "${EXAMPLE_PACKAGE_NAME}" ]]; then
        log "Skipping example: ${EXAMPLE_PACKAGE_NAME}"
        continue
    fi

    log "Recreating shared derived data directory: ${SHARED_DERIVED_DATA_PATH}"
    rm -rf "${SHARED_DERIVED_DATA_PATH}"
    mkdir -v "${SHARED_DERIVED_DATA_PATH}"

    log "Recreating shared example harness directory: ${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"
    rm -rf "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"
    mkdir -v "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"

    log "Copying example contents from ${EXAMPLE_PACKAGE_NAME} to ${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}"
    git archive HEAD "${EXAMPLE_PACKAGE_PATH}" --format tar | tar -C "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}" -xvf- --strip-components 2

    # GNU tar has --touch, but BSD tar does not, so we'll use touch directly.
    log "Updating mtime of example contents..."
    find "${SHARED_EXAMPLE_HARNESS_PACKAGE_PATH}" -print0 | xargs -0 -n1 touch -m

    # There is no CLI to modify dependencies, revert to sed
    log "Re-overriding dependency in ${EXAMPLE_PACKAGE_NAME} to use ${PACKAGE_PATH}"
    PBXPROJ_PATH=$(find $SHARED_EXAMPLE_HARNESS_PACKAGE_PATH -name "project.pbxproj" -type f -maxdepth 2)
    sed -i '' "s|${ORIGINAL_LOCAL_DEPENDENCY_PATH}|${PACKAGE_PATH}|g" "$PBXPROJ_PATH"

    PROJECT_PATH=$(find $SHARED_EXAMPLE_HARNESS_PACKAGE_PATH -name "*.xcodeproj" -type d -maxdepth 1)

    log "Building example app: ${EXAMPLE_PACKAGE_NAME}"
    "${XCODEBUILD_BIN}" build \
        -project "${PROJECT_PATH}" \
        -scheme "${EXAMPLE_PACKAGE_NAME}" \
        -destination "${XCODEBUILD_DESTINATION}" \
        -packageCachePath "${SHARED_PACKAGE_CACHE_PATH}" \
        -clonedSourcePackagesDirPath ${SHARED_CLONED_SOURCES_PATH} \
        -skipPackageUpdates \
        -derivedDataPath "${SHARED_DERIVED_DATA_PATH}"
    log "✅ Successfully built the example app ${EXAMPLE_PACKAGE_NAME}."
done
