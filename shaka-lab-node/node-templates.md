# Shaka Lab Node: Templates

The templates provided by the package are currently not treated as a "config
file" by the various packaging systems, and therefore can be overwritten by
updates.  If you would like to make changes to the templates to add new
browsers, please consider upstreaming those changes in a PR.


## Provided Templates

Templates are provided for all major evergreen browsers, plus all backends
supported by [Generic WebDriver Server](https://github.com/shaka-project/generic-webdriver-server):

See [`node-templates.yaml`](node-templates.yaml) for a current list of
templates and their parameters.


## Basic Templates

A template looks like this:

```yaml
chrome:
  capabilities:
    browserName: chrome
```

At a minimum, there is a `capabilities` object that the Selenium hub will use
to match this node with an incoming request.  You can also define properties
that will be passed to Selenium.  For example, you can specify a particular
driver executable:

```yaml
chrome-android:
  defs:
    webdriver.chrome.driver: ./chromedriver-android$exe
  capabilities:
    browserName: chrome
    platform: Android
```


## Generic WebDriver Server

If you have a node based on [Generic WebDriver Server](https://github.com/shaka-project/generic-webdriver-server),
there are some additional fields and standard properties required by that
system.  For example:


```yaml
edge:
  generic-webdriver-server: true
  defs:
    genericwebdriver.browser.name: msedge
    genericwebdriver.backend.exe: ./msedgedriver$exe
  capabilities:
    browserName: msedge
```

The `generic-webdriver-server` flag tells the package to load Generic WebDriver
Server into the Selenium node.  The properties `genericwebdriver.browser.name`
and `genericwebdriver.backend.exe` are required by Generic WebDriver Server.


## Template parameters

Templates can have parameters which are filled in by the final config file.
For example:

```yaml
xboxone:
  generic-webdriver-server: true
  params:
    - hostname
    - username
    - password
    - ?msbuild  # optional
  defs:
    genericwebdriver.browser.name: xboxone
    genericwebdriver.backend.exe: node_modules/.bin/xbox-one-webdriver-server$cmd
    genericwebdriver.backend.params.hostname: $hostname
    genericwebdriver.backend.params.username: $username
    genericwebdriver.backend.params.password: $password
    genericwebdriver.backend.params.msbuild: $msbuild
  capabilities:
    browserName: xboxone
```

Here, the template has parameters `hostname`, `username`, `password`, and
`msbuild`.  The `?` in `?msbuild` indicates that it is an optional parameter.
The property definitions passed to Selenium then reference those as variables,
such as `$hostname`, `$username`, etc.


## Built-in Variables

Some built-in variables are provided to ease common cross-platform issues:
 - `$exe` will be replaced with .exe on Windows and a blank string otherwise.
 - `$cmd` will be replaced with .cmd on Windows and a blank string otherwise.
