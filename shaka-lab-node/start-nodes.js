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

// Reads Shaka Lab Node config file and Node templates, then launches the
// necessary Selenium node processes.


const childProcess = require('child_process');
const fs = require('fs');
const yaml = require('js-yaml');

// TODO: Generalize paths for Windows
const configPath = '/etc/shaka-lab-node-config.yaml';
const seleniumNodePath = '/opt/shaka-lab/selenium-node';
const templatesPath = `${seleniumNodePath}/node-templates.yaml`;
const genericWebdriverServerJarPath =
    `${seleniumNodePath}/node_modules/generic-webdriver-server/GenericWebDriverProvider.jar`;
const seleniumStandaloneJarPath =
    `${seleniumNodePath}/selenium-server-standalone-3.141.59.jar`;

const templates = yaml.load(fs.readFileSync(templatesPath, 'utf8'));
const config = yaml.load(fs.readFileSync(configPath, 'utf8'));

function requiredField(config, path, field, prefix='') {
  if (!config || !(field in config)) {
    console.error(`Missing required field "${prefix}${field}" in ${path}`);
    process.exit(1);
  }
  return config[field];
}

function loadTemplate(templateName) {
  if (!(templateName in templates)) {
    console.error(
        `Unknown template "${templateName}" in ${configPath},` +
        ` not defined in ${templatesPath}`);
    process.exit(1);
  }

  return templates[templateName];
}

function requiredParam(nodeConfig, templateName, paramName) {
  if (!nodeConfig.params || !(paramName in nodeConfig.params)) {
    console.error(
        `Required param "${paramName}" missing in instantiation` +
        ` of template "${templateName}" in ${configPath}.`);
    process.exit(1);
  }

  return nodeConfig.params[paramName];
}

function optionalParam(nodeConfig, paramName) {
  if (nodeConfig.params && paramName in nodeConfig.params) {
    return nodeConfig.params[paramName];
  }
  return '';
}

function substituteParams(string, params) {
  for (const key in params) {
    const value = params[key];
    const regex = new RegExp('\\$\\b' + key + '\\b');
    string = string.replace(regex, value);
  }
  return string;
}

function stopAllProcesses(processes) {
  for (const process of processes) {
    if (process.exitCode == null) {
      // Still running.  Stop it.
      process.kill();
    }
  }
}

function main() {
  const hub = requiredField(config, configPath, 'hub');
  const nodeConfigs = requiredField(config, configPath, 'nodes');
  const nodeCommands = [];

  // Process the node configs and build a list of commands to launch.
  for (const nodeConfig of nodeConfigs) {
    const templateName = requiredField(
        nodeConfig, configPath, 'template', 'nodes[].');
    const template = loadTemplate(templateName);

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

    const genericWebdriverServer = template['generic-webdriver-server'];
    const defs = template.defs;
    const capabilities = requiredField(
        template, templatesPath, 'capabilities', `${templateName}.`);

    // We always start with the "java" command.
    const args = ['java'];

    // There may be java definitions to set.
    if (defs) {
      for (const key in defs) {
        const value = substituteParams(defs[key], params);
        args.push(`-D${key}=${value}`);
      }
    }

    if (genericWebdriverServer) {
      // Preload GenericWebDriverServer and launch Selenium after.
      args.push('-cp');
      args.push(
          `${genericWebdriverServerJarPath}:${seleniumStandaloneJarPath}`);
      args.push('org.openqa.grid.selenium.GridLauncherV3');
    } else {
      // Launch Selenium directly.
      args.push('-jar', seleniumStandaloneJarPath);
    }

    // Standard configs for role & timeouts.
    args.push('-role', 'node');
    args.push('-timeout', '30', '-browserTimeout', '1200');
    args.push('-register', 'true', '-registerCycle', '5000');

    // The hub to register to.
    args.push('-hub', hub);

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

    // TODO: See if we need to specify additional options on Windows
    const process = childProcess.spawn(command, args, {
      // Run from the package's folder.
      cwd: seleniumNodePath,
      // Ignore stdin, pass stdout and stderr to the parent process.
      stdio: ['ignore', 'inherit', 'inherit'],
    });

    process.once('error', () => {
      stopAllProcesses(processes);
    });
    process.once('exit', () => {
      stopAllProcesses(processes);
    });

    processes.push(process);
  }

  // Now the nodejs process will remain open until either all subprocesses stop
  // or until the script itself is killed.  If the script is killed, all
  // subprocesses will stop, because they are not "detached".  If a subprocess
  // is killed or otherwise dies, the script will respond by shutting down all
  // others.
}

main();
