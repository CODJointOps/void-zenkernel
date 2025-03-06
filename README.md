# void-zenkernel

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Made with Love](https://img.shields.io/badge/Made%20with-%E2%9D%A4-red)

## Precompiled binaries now available

Precompiled Zen Kernel packages are available through our repository. Add our repo and install with:

```bash
echo "repository=https://deadzone.enterprises/repo/x86_64" | sudo tee /etc/xbps.d/10-deadzone.conf
sudo xbps-install -S linux6.13-zen linux6.13-zen-headers
```

## Description

`void-zenkernel` is a collection of packages that allow users to build the Zen Kernel for Void Linux using either GCC or Clang compilers. The Zen Kernel is known for its performance tweaks and smoother system performance. With `void-zenkernel`, Void Linux users can easily harness the power of Zen!

## Features

- Seamless integration with Void Linux.
- Support for both GCC and Clang compilers.
- Regular updates and patches to ensure the best performance.

## Requirements

- Void Linux distribution.
- Development tools (base-devel) installed.
- Either GCC or Clang compiler.