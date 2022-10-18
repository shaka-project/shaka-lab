# Distribution of Debian/Ubuntu packages

Packages will be built in GitHub Actions and served via GitHub Pages in a
[Debian Repository format](https://wiki.debian.org/DebianRepository).
The GitHub Pages deployment will allow users to use `add-apt-repository` and
receive automatic updates to their Linux packages.


## Setup for maintainers

1. Create a GPG key with `gpg --full-gen-key`
 - RSA (sign only)
 - Key size 4096 bits
 - Real name "Shaka Lab"
 - Email "nomail@shakalab.rocks"
2. Export the secret key
 - `gpg --list-secret-keys nomail@shakalab.rocks`
 - `gpg --export-secret-keys -o key nomail@shakalab.rocks`
 - `base64 < key`
3. Copy the base64 key into GitHub as a repository secret named `DEB_GPG_KEY`
4. Remove the exported secret key file with `rm key`

The `release.yaml` workflow will use the stored GPG key to sign packages.
