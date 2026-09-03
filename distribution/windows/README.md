# Distribution of Chocolatey packages for Windows

[Chocolatey packages](https://chocolatey.org/) for Windows must be served from
an active server, and unlike Linux packages, can't be served as static content
from GitHub Pages.  Instead, the packages will be deployed to Vercel via the
[chocolatey-shaka-lab repo](https://github.com/shaka-project/chocolatey-shaka-lab),
to be served by
[express-chocolatey-server](https://github.com/shaka-project/express-chocolatey-server).

This deployment will allow users to use the `choco source add` command and
update with `choco upgrade`.


## Setup for maintainers

1. Create a Vercel project using a shared account, with the following settings:
   - Git connection to https://github.com/shaka-project/chocolatey-shaka-lab
   - Environment `Production` tracking branch `main`, with domain
     `chocolatey.shakalab.rocks` and variable `PORT` set to `3000`
   - Build and deployment framework preset `Express` with:
     - Overrides:
       - Output directory: `.`
       - Install command: `npm ci`
     - Root directory: `.`
     - Node.js version: `24.x`
2. Configure DNS for above domain as requested by Vercel
3. Create a GitHub repository secret named `CHOCOLATEY_TAP_REPO` with the value
   `shaka-project/chocolatey-shaka-lab` (not a true secret, but configurable in
   forks)

The `release.yaml` workflow will deploy updates to the Vercel-connected repo,
which triggers Vercel to update its deployment.
