#!/bin/bash

set -eu

# Convert all .gyb files in the repo outside the .build directory.
find . -name '*.gyb' | grep -v '.build/' | \
    while read -r file; do \
        ./scripts/gyb --line-directive '' -o "${file%.gyb}" "$file"; \
    done
