# Shaka Lab GitHub Runner

The Shaka Lab GitHub Runner package will register one or more GitHub Actions
Runners to your project.  These self-hosted runners will run in Docker, and
will be wiped every time a job is complete.  You can configure the runner scope
(specific repo or organization) and the number of runners (which should not
exceed the number of processors).

This package is available for **Linux only**.

## Pre-requisites

To register a self-hosted runner on GitHub, you must have admin access to the
desired runner scope (a repo or an organization).  You will need to generate a
personal access token from an admin account with the `repo` scope for
repositories, or the `admin:org` scope for organizations.

See https://docs.github.com/en/rest/actions/self-hosted-runners for details.

## Configuration

You can pre-configure the package as shown in the installation section below,
or you can simply install the package and be prompted for the necessary
configs.  This section will explain the configuration options and how you
should set them.

To attach a runner to a specific GitHub repo, set the scope to "repo" and the
scope name to the URL of the GitHub repo (e.g.
"https://github.com/shaka-project/shaka-player").  The access token must have
`repo` permissions.

To attach a runner to an organization, set the scope to "org" and the scope
name to the name of the GitHub organization (e.g. "shaka-project").  The access
token must have `admin:org` permissions.

To use a runner for Shaka Player testing workflows, set the labels to
`self-hosted-selenium`, and set the number of runners to the number of
processors or the number of Selenium nodes you are running, whichever is
smaller.

To use a runner for Shaka Packager workflows on arm64, set the labels to
`self-hosted-linux-arm64`, and set the number of runners to 1.

For your own workflows, set the labels to whatever your workflow expects, and
set the number of runners to whatever is appropriate for the resources
available on the device.

## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update

# Configure your GitHub details before installation to avoid prompting.
# Note that support_nested_containers is incompatible with number_of_runners
# greater than 1.
cat << EOF | sudo debconf-set-selections
shaka-lab-github-runner shaka-lab-github-runner/scope select SCOPE
shaka-lab-github-runner shaka-lab-github-runner/scope_name string SCOPE_NAME
shaka-lab-github-runner shaka-lab-github-runner/access_token password ACCESS_TOKEN
shaka-lab-github-runner shaka-lab-github-runner/labels string LABELS
shaka-lab-github-runner shaka-lab-github-runner/number_of_runners string NUMBER
shaka-lab-github-runner shaka-lab-github-runner/support_nested_containers boolean TRUE_OR_FALSE
EOF

# Install the package, which will not have to prompt for anything thanks to
# the configuration above.
sudo apt -y install shaka-lab-github-runner
```

To change your configuration later, run:

```sh
dpkg-reconfigure shaka-lab-github-runner
```

## Ports

In case you run multiple runner instances on one host, each runner instance is
allocated a unique port number to use in your workflows.  This is passed
through the environment variable `ALLOCATED_PORT`, which you can read in your
workflows.

## Certs

If your workflow needs HTTPS certificates (as the Shaka Player testing
workflows do), then you should also look at the
[`shaka-lab-cert-generator`](../shaka-lab-cert-generator/README.md#readme)
and possibly
[`shaka-lab-cert-receiver`](../shaka-lab-cert-receiver/README.md#readme)
packages.  If one of these is installed, the `shaka-lab-github-runner` package
will automatically make those certs accessible to runners under
`/etc/letsencrypt/`.

## Customization

Some Docker environment variables and command-line arguments are set by the
package installation scripts, but you can customize others.

`/etc/shaka-lab-github-runner.env` contains the environment variables set by
the package installation scripts.  This includes critical settings like the
GitHub access token, scope details, and labels.  Please **do not edit this
manually**.  To modify the configuration, see the `dpkg-reconfigure` command
above.  To customize the environment or arguments beyond what is offered in the
package configuration, see the options below.

In paths below, `$INSTANCE` represents an instance number, such as 1.  Instance
numbers start at 1, not 0.

To add environment variables that apply to all runner instances, add Docker
environment files to `/etc/shaka-lab-github-runner.env.d/`.

To add environment variables that apply to specific runner instances, add
Docker environment files to `/etc/shaka-lab-github-runner@$INSTANCE.env.d/`.

To add Docker command line arguments that apply to all runner instances, add
them in text files inside `/etc/shaka-lab-github-runner.args.d/`.

To add Docker command line arguments that apply to specific runner instances,
add them in text files inside `/etc/shaka-lab-github-runner@$INSTANCE.args.d/`.


## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

## Stopping the service

```sh
sudo systemctl stop github-actions-runners.target
```

## Starting the service

```sh
sudo systemctl start github-actions-runners.target
```

## Logs

To watch live logs from instance 1 (for example):

```sh
journalctl -f -u github-actions-runner@1.service
```

## Uninstallation

```sh
sudo apt remove -y shaka-lab-github-runner
```
