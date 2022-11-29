# Shaka Lab Node: Configuration

The node configuration file is called `shaka-lab-node-config.yaml`, and lives
in a different location per platform:

 - Linux: `/etc/shaka-lab-node-config.yaml`
 - Windows: `c:\ProgramData\shaka-lab-node\node-config.yaml`

A default config is provided on installation, which contains only Chrome, but
has commented sections for every supported browser.  For the latest version of
this for reference, please see
[`shaka-lab-node-config.yaml`](shaka-lab-node-config.yaml) in the repository.


**NOTE**: After editing the configuration, you **must** restart the service!
See per-platform instructions for that in the platform-specific guides:

 - [Linux](linux/README.md#readme)
 - [Windows](windows/README.md#readme)


## Host Configuration

The node configuration file has two fields related to hosts.  The first is
`hub`, which is the address of the Selenium hub:

```yaml
# The Selenium hub to connect to.  Customize this to your local grid.
# If you install shaka-lab-hub with a default config on the same machine,
# this will be correct.
hub: http://127.0.0.1:4444/
```

This is a required field.

The second is `host`, which is the local hostname or IP address for the
Selenium node:

```yaml
# Optional: The local hostname or IP to listen on.
# For some systems with multiple IPs, you may need this to get the nodes
# properly registered.
#host: 192.168.1.55
```

This field is optional, but may be necessary for systems with multiple IPs.
Devices running Docker or using VPNs are very likely to have multiple IPs.


## Template Instantiation

The details of Selenium configuration are kept in templates (see
[`node-templates.md`](node-templates.md) for details).  The node configuration
file specifies which templates to instantiate, and with which parameters (if
any).  For example:

```yaml
nodes:
  - template: chrome
```

This instantiates the `chrome` template, with no parameters.  (This template
doesn't require any.)

Some templates have required parameters.  For example, this template:

```yaml
chromecast:
  generic-webdriver-server: true
  params:
    - hostname
    - version
  defs:
    genericwebdriver.browser.name: chromecast
    genericwebdriver.backend.exe: node_modules/.bin/chromecast-webdriver-server$cmd
    genericwebdriver.backend.params.hostname: $hostname
  capabilities:
    browserName: chromecast
    version: $version
```

This template requires the parameters `hostname` and `version` in order to
build the correct Selenium node command.  To instantiate a template like this
one, add a `params` object:

```yaml
nodes:
  - template: chromecast
    params:
      hostname: shaka-test-chromecast-ultra
      version: Ultra
```

If you are unsure what parameters are supported by any given template, the
`node-templates.yaml` file is the source of truth for this.

Some template parameters are optional, indicated by a leading question mark:

```yaml
tizen:
  generic-webdriver-server: true
  params:
    - hostname
    - ?ethaddr  # optional
    - version
  defs:
    genericwebdriver.browser.name: tizen
    genericwebdriver.backend.exe: node_modules/.bin/tizen-webdriver-server$cmd
    genericwebdriver.backend.params.hostname: $hostname
    genericwebdriver.backend.params.wake-on-lan-address: $ethaddr
  capabilities:
    browserName: tizen
    version: $version
```

In this example, an instantiation would require `hostname` and `version`, but
not `ethaddr`:

```yaml
nodes:
  # NOTE: Tizen nodes require Docker: sudo apt install docker.io
  - template: tizen
    params:
      hostname: shaka-test-tizen
      version: 3
```


## Multiple Nodes

The examples given above only show a single node.  Multiple nodes are specified
by continuing the YAML list in the `nodes` field, which looks like this:

```yaml
hub: http://127.0.0.1:4444/

nodes:
  - template: chrome

  - template: firefox

  - template: edge

  - template: safari

  - template: safari-tp

  - template: chrome-android

  - template: chromecast
    params:
      hostname: shaka-test-chromecast-ultra
      version: Ultra
```


## Overriding Definitions

A node config may override or augment definitions specified in the template.
For example, to pass an additional argument to
[Chromecast WebDriver Server](https://github.com/shaka-project/generic-webdriver-server/tree/main/backends/chromecast),
you could do something like this:

```yaml
nodes:
  - template: chromecast
    params:
      hostname: shaka-test-chromecast-ultra
      version: Ultra
    defs:
      genericwebdriver.backend.params.receiver-app-id: B602D163
```
