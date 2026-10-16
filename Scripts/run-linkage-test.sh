#!/bin/bash

set -eu

# Validate that we're running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script must be run on Linux. Current OS: $(uname -s)" >&2
    exit 1
fi

echo "Running on Linux - proceeding with linkage test..."

# Build the linkage test package
echo "Building linkage test package..."
swift build --package-path Tests/LinkageTest

# Ask SwiftPM for the build output directory, as its layout differs between build systems
BIN_PATH=$(swift build --package-path Tests/LinkageTest --show-bin-path)
BUILD_PATH="$BIN_PATH/configurationLinkageTest"

# Verify the binary exists
if [[ ! -f "$BUILD_PATH" ]]; then
    echo "Error: Built binary not found at $BUILD_PATH" >&2
    exit 1
fi

echo "Checking linkage for binary: $BUILD_PATH"

# Run ldd and check if libFoundation.so is linked
LDD_OUTPUT=$(ldd "$BUILD_PATH")
echo "LDD output:"
echo "$LDD_OUTPUT"

if echo "$LDD_OUTPUT" | grep -q "libFoundation.so"; then
    echo "Error: Binary is linked against libFoundation.so - this indicates incorrect linkage. Ensure the full Foundation is not linked on Linux when default traits are disabled." >&2
    exit 1
else
    echo "Success: Binary is not linked against libFoundation.so - linkage test passed."
fi
