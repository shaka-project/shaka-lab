# The shaka-lab-node app on macOS

## What it is

The services start from `/Applications/shaka-lab-node.app`, an Automator
application, which the package adds as a login item for the GUI user.  It has
one "Run Shell Script" action, which runs `/opt/shaka-lab-node/launch.sh`.
`restart-services.sh` starts the same app.

It's an app, and not a launchd agent, because macOS 15 gates local network
access per application, and never shows launchd agents the prompt to allow it.
An app in `/Applications` that runs as a login item gets past that.  See
[local-network-privacy.md](local-network-privacy.md) and commit 26bb89b.

The app's source is in this repo, as the whole `.app` bundle, in
`shaka-lab-node.app`.  The script it runs is the `COMMAND_STRING` value in
`Contents/document.wflow`.

## Changing it

Keep the app's script as small as it is now, and put any logic in
`launch.sh`, which the package installs owned by root.  Then changes never
have to touch the app bundle.

If the app's script does have to change, either edit `COMMAND_STRING` in
`Contents/document.wflow` as text, or open the app in Automator, change the
action, and save.  Either works, for the reasons in the next section.

## Signing

Automator signs an app ad hoc when it saves it.  An ad hoc signature uses no
identity or certificate, so there is nothing to look up or reuse, and a lab
replicating this setup doesn't need an Apple developer account.

That signature doesn't survive git.  codesign stores the signature of
`Contents/document.wflow`, which isn't a binary, in extended attributes on the
file, and git doesn't keep extended attributes.  So every copy checked out
from git, and every copy the package installs, already fails verification:

```sh
codesign --verify --deep --strict /Applications/shaka-lab-node.app
# code object is not signed at all
# In subcomponent: /Applications/shaka-lab-node.app/Contents/document.wflow

spctl --assess --type execute /Applications/shaka-lab-node.app
# rejected (source=no usable signature)
```

Re-signing after a change would be undone the next time the app goes through
git, so don't bother.

## Why it runs anyway

macOS only checks an app's signature this way (with Gatekeeper) when the app
is quarantined, which is what happens to apps downloaded by a browser.
Nothing quarantines this one: Homebrew gets the tap with git, and `install.sh`
copies the app into `/Applications` with `cp`.

If a lab ever installs the app some other way that adds the
`com.apple.quarantine` extended attribute, Gatekeeper will block it.  Check
with `xattr -p com.apple.quarantine /Applications/shaka-lab-node.app`, which
should say there is no such attribute.
