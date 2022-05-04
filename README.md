# Shaka Lab Packages


## Overview

This is all the software needed to replicate the private lab environment used to
build and test [Shaka Player](https://github.com/shaka-project/shaka-player),
[Shaka Packager](https://github.com/shaka-project/shaka-packager), and others.


## High-Level Goals

 - Speedy recovery after a disaster (disk corruption, exploding battery, etc)
 - Allow partners to replicate and contribute to our testing infrastructure
 - Replace aging, incomplete manual setup docs with version-controlled code


## Description

The Shaka Lab is composed of a
[Selenium grid](https://www.selenium.dev/documentation/grid/) and other
services running on multiple devices and operating systems.  Below are links to
dedicated docs on each package.

Setup involves installing relevant OS packages, editing configuration files,
and restarting services.  The available packages, config file locations, and
service commands vary by OS.

Package systems:
 - For Linux, [Debian](https://www.debian.org/)/[Ubuntu](https://ubuntu.com/)
   packages
 - For Windows, [Chocolatey](https://chocolatey.org/) packages
 - For macOS, [Homebrew](https://brew.sh/) formulae

Everything in this repo is licensed under [Apache license v2.0](LICENSE.txt).


## Package Guides

 - [Shaka Lab Hub](shaka-lab-hub/README.md) - Selenium grid hub (Linux only)
