# Hello World App Example

> **Disclaimer:** This example is designed to demonstrate basic concepts of Swift Configuration and is not production-ready code. It lacks comprehensive error handling, testing, and other features required for production use.

## Overview

This example demonstrates the fundamental concepts of Swift Configuration through a simple app that displays a personalized greeting message. The application showcases how to:

- Set up multiple configuration providers in a hierarchy.
- Use environment variables and in-memory arguments as configuration sources.
- Read configuration values with type safety and default fallbacks.

## What it does

The application reads a `greetedName` configuration value from multiple sources and displays `"Hello, {name}!"`. The configuration sources are prioritized as follows:

1. **Environment variabless** (highest priority)
2. **In-memory configuration** (lower priority)
3. **Default value** (`"World"` - used when no other source provides the value)

## Step-by-step instructions

### Step 1: Build the example

Open the project in Xcode, and select a target destination.

### Step 2: Run with default value

Run the application without any configuration to see the default behavior:

**Expected output:**
```
Hello, Memory!
```

### Step 3: Run with environment variable

Edit the current scheme and set the `GREETED_NAME` environment variable, then run the application:

**Expected output:**
```
Hello, Environment!
```

This demonstrates that environment variables take precedence over in-memory configuration in the provider hierarchy.
