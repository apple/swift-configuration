## Legal

By submitting a pull request, you represent that you have the right to license
your contribution to Apple and the community, and agree by submitting the patch
that your contributions are licensed under the Apache 2.0 license (see
`LICENSE.txt`).

## How to submit a bug report

Please report any issues related to this library in the [swift-configuration](https://github.com/apple/swift-configuration/issues) repository.

Specify the following:

* Swift Configuration version
* Contextual information (e.g. what you were trying to achieve with swift-configuration)
* Simplest possible steps to reproduce
  * More complex the steps are, lower the priority will be.
  * A pull request with failing test case is preferred, but it's just fine to paste the test case into the issue description.
* Anything that might be relevant in your opinion, such as:
  * Swift version or the output of `swift --version`
  * OS version and the output of `uname -a`
  * Network configuration

### Example

```
Swift Configuration version: 1.0.0

Context:
While testing my application that uses with swift-configuration, I noticed that ...

Steps to reproduce:
1. ...
2. ...
3. ...
4. ...

$ swift --version
Swift version 4.0.2 (swift-4.0.2-RELEASE)
Target: x86_64-unknown-linux-gnu

Operating system: Ubuntu Linux 16.04 64-bit

$ uname -a
Linux beefy.machine 4.4.0-101-generic #124-Ubuntu SMP Fri Nov 10 18:29:59 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux

My system has IPv6 disabled.
```

## Contributing a pull request

1. Review the [Developing Swift Configuration](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/development) documentation.
2. Prepare your change, keeping in mind that a good patch is:
  - Concise, and contains as few changes as needed to achieve the end result.
  - Tested, ensuring that any tests provided failed before the patch and pass after it.
  - Documented, adding API documentation as needed to cover new functions and properties.
  - Accompanied by a great commit message.
3. Open a pull request at https://github.com/apple/swift-configuration and wait for code review by the maintainers.

## Automated release process

This repository uses automated releases based on semantic versioning labels. See the [swift-temporal-sdk Auto Release Workflow documentation](https://github.com/apple/swift-temporal-sdk/blob/main/.github/workflows/README.md) for details.
