# Developing Swift Configuration

Learn about tools and conventions used to develop the Swift Configuration package.

## Overview

The Swift Configuration package is developed using modern Swift development practices and tools. This guide covers the development workflow, code organization, and tooling used to maintain the package.

### Process

We follow an open process and discuss development on GitHub issues, pull requests, and on the [Swift Forums](https://forums.swift.org/c/server/serverdev/14). Details on how to submit an issue or a pull requests can be found in [CONTRIBUTING.md](https://github.com/apple/swift-configuration/blob/main/CONTRIBUTING.md).

Large features and changes go through a lightweight proposals process - to learn more, check out <doc:Proposals>.

### Repository structure

#### Package organization

The package contains several Swift targets organized by functionality:

- **Configuration** - Core configuration reading APIs and built-in providers.
- **ConfigurationTesting** - Testing utilities for external configuration providers.
- **ConfigurationTestingInternal** - Internal testing utilities and helpers.

### Development tools

#### Running CI checks locally

You can run the Github Actions workflows locally using
[act](https://github.com/nektos/act). To run all the jobs that run on a pull
request, use the following command:

```
% act pull_request
```

To run just a single job, use `workflow_call -j <job>`, and specify the inputs
the job expects. For example, to run just shellcheck:

```
% act workflow_call -j soundness --input shell_check_enabled=true
```

To bind-mount the working directory to the container, rather than a copy, use
`--bind`. For example, to run just the formatting, and have the results
reflected in your working directory:

```
% act --bind workflow_call -j soundness --input format_check_enabled=true
```

If you'd like `act` to always run with certain flags, these can be be placed in
an `.actrc` file either in the current working directory or your home
directory, for example:

```
--container-architecture=linux/amd64
--remote-name upstream
--action-offline-mode
```

#### Code generation with gyb

This package uses the "generate your boilerplate" (gyb) [script](https://github.com/swiftlang/swift/blob/main/utils/gyb.py) from the Swift repository to stamp out repetitive code for each supported primitive type.

The files that include gyb syntax end with `.gyb`, and after making changes to any of those files, run:

```bash
./Scripts/generate_boilerplate_files_with_gyb.sh
```

If you're adding a new `.gyb` file, also make sure to add it to the exclude list in `Package.swift`.

After running this script, also [run the formatter](#code-formatting) before opening a PR.

#### Code formatting

The project uses swift-format for consistent code style. You can run CI checks locally using [`act`](https://github.com/nektos/act).

To run formatting checks:

```bash
act --bind workflow_call -j soundness --input format_check_enabled=true
```

#### Testing

The package includes comprehensive test suites for all components:

- Unit tests for individual providers and utilities.
- Compatibility tests using `ProviderCompatTest` for built-in providers.

Run tests using Swift Package Manager:

```bash
swift test --enable-all-traits
```

#### Documentation

Documentation is written using DocC and includes:

- API reference documentation in source code.
- Conceptual guides in `.docc` catalogs.
- Usage examples and best practices.
- Troubleshooting guides.

Preview documentation locally:

```bash
SWIFT_PREVIEW_DOCS=1 swift package --disable-sandbox preview-documentation --target Configuration
```

### Contributing guidelines

#### Code style

- Follow Swift API Design Guidelines.
- Use meaningful names for types, methods, and variables.
- Include comprehensive documentation for all APIs, not only public types.
- Write unit tests for new functionality.

#### Provider development

When developing new configuration providers:

1. Implement the ``ConfigProvider`` protocol.
2. Add comprehensive unit tests.
3. Run compatibility tests using `ProviderCompatTest`.
4. Add documentation to all symbols, not just `public`.

#### Documentation requirements

All APIs must include:

- Clear, concise documentation comments.
- Usage examples where appropriate.
- Parameter and return value descriptions.
- Error conditions and handling.
