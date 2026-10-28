# Distribution of Homebrew formulae for macOS

[Homebrew taps](https://docs.brew.sh/Taps) (which host macOS package formulae)
require a specific GitHub naming convention and repository layout, and unlike
Linux packages, can't be served as static content from GitHub Pages.  The
necessary repository layout will be built in GitHub Actions and pushed to
[shaka-project/homebrew-shaka-lab](https://github.com/shaka-project/homebrew-shaka-lab),
which satisfies the required name and layout of a Homebrew tap.

This deployment will allow users to use the `brew tap` command and receive
update notifications from Homebrew for their macOS packages.


## Setup for maintainers

1. Create a tap repo (`homebrew-shaka-lab`).
2. Create a classic GitHub Personal Access Token (PAT) for a user with write
   access to the `homebrew-shaka-lab` repo.  For example, we are using
   [`shaka-bot`](https://github.com/shaka-bot).  Since the tap repo is public,
   the access token only needs the `public_repo` scope.  (A private tap repo
   would need the broader `repo` scope instead.)  The same token is also used
   to deploy Windows packages, so the user also needs write access to the
   Chocolatey repo.  See [the Windows docs](../windows/README.md).
3. Copy the PAT into GitHub as a secret on this repository named
   `HOMEBREW_DEPLOY_TOKEN`.
4. Create a GitHub repository secret named `HOMEBREW_TAP_REPO` with the name of
   the repository where the homebrew tap will be deployed.  For example, we are
   using
   [`shaka-project/homebrew-shaka-lab`](https://github.com/shaka-project/homebrew-shaka-lab).

The `release.yaml` workflow will use the stored PAT to push to the homebrew tap
repository.
