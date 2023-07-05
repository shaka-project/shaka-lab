# Distribution of Chocolatey packages for Windows

[Chocolatey packages](https://chocolatey.org/) for Windows must be served from
an active server, and unlike Linux packages, can't be served as static content
from GitHub Pages.  Instead, the packages will be deployed to App Engine to be
served by [express-chocolatey-server](https://github.com/shaka-project/express-chocolatey-server).

This deployment will allow users to use the `choco source add` command and
update with `choco upgrade`.


## Setup for maintainers

1. Create an App Engine project in Google Cloud.
2. Create a service account key in Google Cloud.
3. Copy the key in JSON format to GitHub as a repository secret named
   `APPENGINE_DEPLOY_KEY`.
4. Create a GitHub repository secret named `APPENGINE_PROJECT_ID` with the App
   Engine project ID to deploy to.
5. Create a GitHub repository secret named `APPENGINE_PROJECT_VERSION` with the
   App Engine project version to deploy to.


The `release.yaml` workflow will use the stored key to deploy updates to App
Engine, which will serve the packages.
