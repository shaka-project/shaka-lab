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

// Wrap macOS services for logging purposes.
//
// Services based on launchd for macOS can have their output redirected to a
// log file.  However, this does not rotate logs.  External log rotation
// mechanisms (such as newsyslog) want to signal the log writer to reopen the
// log files on rotation, but launchd doesn't support this signal.
// Therefore, the only way to get service output logging with rotation on macos
// is to have the service itself write the log files and handle signals.
//
// This wrapper allows the service (and its child processes) continue logging
// to stdout and stderr, while leaving the details of logging and signal
// handling to the wrapper.
//
// References:
//  - https://serverfault.com/q/900499
//  - https://stackoverflow.com/q/71832882

const child_process = require('child_process');
const fs = require('fs');

function main() {
  const args = process.argv.slice(2);
  if (args.length < 4) {
    console.log('Usage: node log-wrapper.js' +
                ' <STDOUT-LOG> <STDERR-LOG> <PID-FILE> <COMMAND> [...]');
    console.log('Pass a blank string as a log path to ignore that stream.');
    process.exit(1);
  }

  // Extract arguments.
  const stdoutLogPath = args[0];
  const stderrLogPath = args[1];
  const pidPath = args[2];
  const command = args[3];
  const commandArgs = args.slice(4);  // may be empty

  // File descriptors for logging.
  let stdoutLogFd = null;
  let stderrLogFd = null;

  const tryOpenFd = (path) => {
    // If the path is an empty string, we don't log anything from this stream.
    if (!path) {
      return null;
    }

    try {
      return fs.openSync(path, 'a');
    } catch (error) {
      console.log('Failed to open file:', path);
      console.log(error);
      process.exit(1);
    }
  };

  const closeFd = (fd) => {
    if (fd != null) {
      fs.closeSync(fd);
    }
  }

  const writeToLog = (fd, chunk) => {
    if (fd != null) {
      fs.write(fd, chunk, (error) => {
        if (error) {
          console.log('Failed to write to log file!');
          console.log(error);
          process.exit(1);
        }
      });
    }
  };

  const reopenLogs = () => {
    closeFd(stdoutLogFd);
    closeFd(stderrLogFd);
    stdoutLogFd = tryOpenFd(stdoutLogPath);
    stderrLogFd = tryOpenFd(stderrLogPath);
  };

  reopenLogs();

  // Write the PID file that the log rotator will use to signal us.
  try {
    const pidFd = fs.openSync(pidPath, 'w');
    fs.writeSync(pidFd, process.pid.toString() + '\n');
    fs.closeSync(pidFd);
  } catch (error) {
    console.log('Failed to write PID file:', pidPath);
    process.exit(1);
  }

  const child = child_process.spawn(command, commandArgs, {
    // Ignore stdin, but capture stdout and stderr as pipes.
    stdio: ['ignore', 'pipe', 'pipe'],
    // Make sure children are attached to the parent.
    detached: false,
  });

  child.once('error', (error) => {
    console.log('Failed to spawn child process!');
    console.log(error);
  });
  child.once('spawn', () => {
    console.log('Child process started:', [command].concat(commandArgs));
  });

  child.stdout.on('data', (chunk) => writeToLog(stdoutLogFd, chunk));
  child.stderr.on('data', (chunk) => writeToLog(stderrLogFd, chunk));
  child.stdout.resume();
  child.stderr.resume();

  process.on('SIGHUP', () => {
    console.log('Received SIGHUP, reopening log files.');
    reopenLogs();
  });

  // When _this_ process stops...
  process.once('exit', () => {
    console.log('Exitting.');

    if (child.exitCode == null) {
      // Still running.  Stop it.
      child.kill();
    }
  });
}

main();
