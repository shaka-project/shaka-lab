/* Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @fileoverview
 * Reads Shaka Lab Node config file and node templates, then launches the
 * necessary Selenium node processes.
 */

const child_process = require('child_process');
const fs = require('fs');

// Default: linux settings
let configPath = '/etc/shaka-lab-node-config.yaml';
let shakaLabNodePath = '/opt/shaka-lab/shaka-lab-node';
let workingDirectory = '/opt/shaka-lab/shaka-lab-node';
let updateDrivers = `${shakaLabNodePath}/update-drivers.sh`;
let classPathSeparator = ':';
let exe = '';
let cmd = '';
let javaCommand = 'java';

if (process.platform == 'win32') {
  configPath = 'c:/ProgramData/shaka-lab-node/shaka-lab-node-config.yaml';
  shakaLabNodePath = 'c:/ProgramData/chocolatey/lib/shaka-lab-node';
  workingDirectory = 'c:/ProgramData/shaka-lab-node/';
  updateDrivers = `${shakaLabNodePath}/update-drivers.cmd`;
  classPathSeparator = ';';
  exe = '.exe';
  cmd = '.cmd';
  javaCommand = 'C:/ProgramData/chocolatey/bin/java.exe';
} else if (process.platform == 'darwin') {
  configPath = '/etc/shaka-lab-node-config.yaml';
  shakaLabNodePath = '/opt/shaka-lab-node';
  workingDirectory = '/opt/shaka-lab-node';
  updateDrivers = `${shakaLabNodePath}/update-drivers.sh`;
}

// Paths derived from the OS-specific ones above.
const templatesPath = `${shakaLabNodePath}/node-templates.yaml`;
const genericWebdriverServerJarPath =
    `${workingDirectory}/node_modules/generic-webdriver-server/GenericWebDriverProvider.jar`;
const seleniumStandaloneJarPath =
    `${shakaLabNodePath}/selenium-server-standalone-3.141.59.jar`;

// Common, repeated options for child_process.spawn().
const spawnOptions = {
  // Run from the package's working directory.
  cwd: workingDirectory,
  // Ignore stdin, pass stdout and stderr to the parent process.
  stdio: ['ignore', 'inherit', 'inherit'],
  // Make sure children are attached to the parent.
  detached: false,
};

/**
 * Access a required field from config, and validate its presence.
 *
 * @param {Object<string, *>} config
 * @param {string} path Path to the config file
 * @param {string} field The required field name
 * @param {string} prefix A prefix for the field name, a path to a nested field
 * @return {*}
 */
function requiredField(config, path, field, prefix='') {
  if (!config || !(field in config)) {
    console.error(`Missing required field "${prefix}${field}" in ${path}`);
    process.exit(1);
  }
  return config[field];
}

/**
 * Get a config template, and validate its presence.
 *
 * @param {Array<Object>} templates
 * @param {string} templateName
 * @return {Object}
 */
function getTemplate(templates, templateName) {
  if (!(templateName in templates)) {
    console.error(
        `Unknown template "${templateName}" in ${configPath},` +
        ` not defined in ${templatesPath}`);
    process.exit(1);
  }

  return templates[templateName];
}

/**
 * Access a required param from a node config, and validate its presence.
 *
 * @param {Object} nodeConfig
 * @param {string} templateName
 * @param {string} paramName
 * @return {string}
 */
function requiredParam(nodeConfig, templateName, paramName) {
  if (!nodeConfig.params || !(paramName in nodeConfig.params)) {
    console.error(
        `Required param "${paramName}" missing in instantiation` +
        ` of template "${templateName}" in ${configPath}.`);
    process.exit(1);
  }

  return nodeConfig.params[paramName];
}

/**
 * Access an optional param from a node config, or return a blank default.
 *
 * @param {Object} nodeConfig
 * @param {string} paramName
 * @return {string}
 */
function optionalParam(nodeConfig, paramName) {
  if (nodeConfig.params && paramName in nodeConfig.params) {
    return nodeConfig.params[paramName];
  }
  return '';
}

/**
 * Substitute parameters (such as "$exe") into a config's string value.
 *
 * @param {string} string
 * @param {Object<string, string>} params
 * @return {string}
 */
function substituteParams(string, params) {
  // Don't touch non-strings.
  if (typeof string != 'string') {
    return string;
  }

  for (const key in params) {
    const value = params[key];
    const regex = new RegExp('\\$\\b' + key + '\\b');
    string = string.replace(regex, value);
  }
  return string;
}

/**
 * Stop all child processes.
 *
 * @param {Array<ChildProcess>} processes
 */
function stopAllProcesses(processes) {
  for (const child of processes) {
    if (child.exitCode == null) {
      // Still running.  Stop it.
      try {
        child.kill();
      } catch (error) {
        // Ignore errors if the process is already dead.
      }
    }
  }
}

/**
 * Read configs and templates, and start Selenium nodes as child processes.
 * This parent process will monitor the child processes, and shut them all down
 * if one fails.  The background service system of the OS will log this and
 * restart this parent process as needed.
 */
function main() {
  // Update WebDrivers on startup.
  // This has a side-effect of also installing other requirements, such as
  // js-yaml, which we don't load until we need it below.
  const updateProcess = child_process.spawnSync(
      updateDrivers, /* args= */ [], spawnOptions);
  if (updateProcess.status) {
    throw new Error(
        `Driver update failed with exit code ${updateProcess.status}`);
  }
  if (updateProcess.error) {
    // Hopefully this error object has enough context without us needing to
    // write a custom message or wrap the Error object in any way.  We haven't
    // triggered this in the wild yet.
    throw updateProcess.error;
  }

  const yaml = require('js-yaml');

  const templates = yaml.load(fs.readFileSync(templatesPath, 'utf8'));
  const config = yaml.load(fs.readFileSync(configPath, 'utf8'));

  const hub = requiredField(config, configPath, 'hub');
  const host = config['host'];
  const nodeConfigs = requiredField(config, configPath, 'nodes');
  const nodeCommands = [];

  // Process the node configs and build a list of commands to launch.
  for (const nodeConfig of nodeConfigs) {
    const templateName = requiredField(
        nodeConfig, configPath, 'template', 'nodes[].');
    const template = getTemplate(templates, templateName);

    // Prepare template parameters.
    const params = {};
    if (template.params) {
      for (let paramName of template.params) {
        const optional = paramName.startsWith('?');

        if (optional) {
          paramName = paramName.substr(1);  // remove leading '?'
          params[paramName] = optionalParam(nodeConfig, paramName);
        } else {
          params[paramName] = requiredParam(
              nodeConfig, templateName, paramName);
        }
      }
    }

    // Add platform-specific extensions to the params.
    params['exe'] = exe;
    params['cmd'] = cmd;

    const genericWebdriverServer = template['generic-webdriver-server'];
    const defs = Object.assign(template.defs || {}, nodeConfig.defs || {});
    const capabilities = requiredField(
        template, templatesPath, 'capabilities', `${templateName}.`);

    // We always start with the "java" command.
    const args = [javaCommand];

    // There may be java definitions to set.
    for (const key in defs) {
      const value = substituteParams(defs[key], params);
      if (value) {
        args.push(`-D${key}=${value}`);
      }
    }

    if (genericWebdriverServer) {
      // Preload GenericWebDriverServer and launch Selenium after.
      args.push('-cp');
      args.push(
          genericWebdriverServerJarPath + classPathSeparator +
          seleniumStandaloneJarPath);
      args.push('org.openqa.grid.selenium.GridLauncherV3');
    } else {
      // Launch Selenium directly.
      args.push('-jar', seleniumStandaloneJarPath);
    }

    // Standard configs for role & timeouts.
    args.push('-role', 'node');
    args.push('-timeout', '30', '-browserTimeout', '1200');
    args.push('-register', 'true', '-registerCycle', '5000');

    // This allows us to connect to Android browsers over adb from any platform.
    // Normally, Selenium wipes your capabilities if they don't match the host
    // OS, causing a bogus registration to the hub.  Since Android is seen as
    // part of the "Linux" family by Selenium, we need this behavior disabled
    // to host Android devices on Windows or Mac nodes.
    args.push('-enablePlatformVerification', 'false');

    // The hub to register to.
    args.push('-hub', hub);

    // If a local IP/hostname is specified, tell Selenium to listen on that.
    // For some systems with multiple interfaces, you may need this config to
    // get nodes properly registered.
    if (host) {
      args.push('-host', host);
    }

    // The capabilities this node will declare to the grid.  May include
    // template parameters.
    const capabilitiesArray = [];
    for (const key in capabilities) {
      const value = substituteParams(capabilities[key], params);
      capabilitiesArray.push(`${key}=${value}`);
    }
    args.push('-capabilities', capabilitiesArray.join(','));

    nodeCommands.push(args);
  }

  // Launch the node commands.  If any of them fail, shut down the others.
  const processes = [];
  for (const args of nodeCommands) {
    const command = args.shift();

    const child = child_process.spawn(command, args, spawnOptions);

    child.once('error', (event) => {
      console.log('Child process errored.', event);
      stopAllProcesses(processes);
      process.exit(1);
    });
    child.once('exit', (event) => {
      console.log('Child process exited.', event);
      stopAllProcesses(processes);
      process.exit(1);
    });

    processes.push(child);
  }

  // If shut down politely, exit with code 0.
  // This is important, as it will not trigger a restart on macOS.
  // Without this, there is no way to shut down a service on macOS explicitly
  // without the keepAlive setting starting it again.
  process.once('SIGTERM', () => {
    console.log('Received SIGTERM.  Quitting.');
    process.exit(0);
  });

  // Add an explicit handler to kill all processes when _this_ process stops.
  // This seems to help with service shut down on Windows, which would
  // otherwise leave the child processes orphaned and running.
  process.once('exit', () => {
    console.log('Exit event.');
    stopAllProcesses(processes);
  });

  // Now the nodejs process will remain open until either all subprocesses stop
  // or until the script itself is killed.  If a subprocess is killed or
  // otherwise dies, the script will respond by shutting down all others.
}

main();
