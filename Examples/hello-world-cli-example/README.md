# Hello World CLI Example

> **Disclaimer:** This example is designed to demonstrate basic concepts of Swift Configuration and is not production-ready code. It lacks comprehensive error handling, testing, and other features required for production use.

## Overview

This example demonstrates the fundamental concepts of Swift Configuration through a simple command-line interface that prints a personalized greeting message. The application showcases how to:

- Set up multiple configuration providers in a hierarchy.
- Use environment variables and command-line arguments as configuration sources.
- Read configuration values with type safety and default fallbacks.

## What it does

The CLI application reads a `greetedName` configuration value from multiple sources and prints `"Hello, {name}!"`. The configuration sources are prioritized as follows:

1. **Command-line arguments** (highest priority)
2. **Environment variables** (lower priority)
3. **Default value** (`"World"` - used when no other source provides the value)

## Step-by-step instructions

### Step 1: Build the example

Navigate to the example directory and build the executable:

```zsh
cd Examples/hello-world-cli-example
swift build
```

### Step 2: Run with default value

Run the application without any configuration to see the default behavior:

```zsh
swift run CLI
```

**Expected output:**
```zsh
Hello, World!
```

### Step 3: Run with environment variable

Set the `GREETED_NAME` environment variable and run the application:

```zsh
GREETED_NAME="Swift" swift run CLI
```

**Expected output:**
```
Hello, Swift!
```

### Step 4: Run with command-line argument

Provide the configuration via command-line argument:

```zsh
swift run CLI --greeted-name "Developer"
```

**Expected output:**
```
Hello, Developer!
```

### Step 5: Demonstrate provider priority

Show how command-line arguments override environment variables by providing both:

```zsh
GREETED_NAME="EnvValue" swift run CLI --greeted-name "CLIValue"
```

**Expected output:**
```
Hello, CLIValue!
```

This demonstrates that command-line arguments take precedence over environment variables in the provider hierarchy.
