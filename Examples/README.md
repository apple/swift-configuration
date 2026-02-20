# Swift Configuration examples

This directory contains examples demonstrating various Swift Configuration features and patterns.

## Overview

The examples are organized by complexity and use case, starting with basic concepts and progressing to more advanced scenarios. Each example includes step-by-step instructions, expected output, and explanations of the Swift Configuration concepts being demonstrated.

## Getting started

### Running examples

Each example is a self-contained Swift package. Navigate to the specific example directory and use standard Swift Package Manager commands:

```zsh
cd Examples/{example-name}
swift build
swift run {target-name}
```

## Examples catalog

| Example | Description | Key Concepts |
|---------|-------------|--------------|
| [`hello-world-cli-example`](hello-world-cli-example/) | Simple CLI demonstrating provider hierarchy and basic configuration reading | Provider priority, environment variables, command-line arguments, type-safe reading |
| [`reloading-example`](reloading-example/) | Simple web server demonstrating live reloading from a Kubernetes configMap | Live-reloading, file providers, multi-phase initialization |
