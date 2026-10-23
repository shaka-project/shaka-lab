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
// This wrapper allows the service (and its child processes) to continue
// logging to stdout and stderr, while leaving the details of logging and
// signal handling to the wrapper.
//
// Since the wrapper also restarts the service when it exits, launchd never
// sees the service stop, and so never cleans up after it.  So the wrapper does
// that too, the way systemd would on Linux: the service runs in its own process
// group, and whatever is left in that group when the service exits gets killed.
// This matters because processes orphaned by the service, such as a
// safaridriver whose Selenium node was killed, can hold on to resources the
// next run of the service needs.
//
// The service's PID, which is also its process group ID, is written next to
// the wrapper's own PID file, with ".pid" replaced by ".child.pid".  This lets
// stop-services.sh clean up the service even if the wrapper is already gone.
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
  const childPidPath = pidPath.replace(/(\.pid)?$/, '.child.pid');

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

  let child = null;
  let quitting = false;

  // The process group of the most recent child, which leads its own group.
  // This outlives the child itself, so that anything it left behind can still
  // be found and killed.
  let childGroupId = null;

  // Signal everything in the child's process group, if anything is left.
  const signalChildGroup = (signal) => {
    if (childGroupId == null) {
      return;
    }

    try {
      // The negative number is interpreted as a group ID instead of a PID.
      process.kill(-childGroupId, signal);
    } catch (error) {
      // Ignore errors if the group is already empty.
    }
  };

  const childGroupIsEmpty = () => {
    try {
      // Signal 0 checks for existence without sending anything.
      process.kill(-childGroupId, 0);
      return false;
    } catch (error) {
      return true;
    }
  };

  const spawnChild = () => {
    if (quitting) {
      return;
    }

    // The previous child's group was sent SIGTERM when the child exited.
    // Force out anything that ignored it before starting over.
    signalChildGroup('SIGKILL');

    child = child_process.spawn(command, commandArgs, {
      // Ignore stdin, but capture stdout and stderr as pipes.
      stdio: ['ignore', 'pipe', 'pipe'],
      // Put the child in its own process group, so that we can find and kill
      // everything it spawned, even after the child itself is gone.
      detached: true,
    });

    if (child.pid != null) {
      childGroupId = child.pid;
      try {
        fs.writeFileSync(childPidPath, child.pid.toString() + '\n');
      } catch (error) {
        console.log('Failed to write child PID file:', childPidPath);
        console.log(error);
      }
    }

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

    child.once('exit', (code, signal) => {
      console.log(`Child process exited with code ${code}, signal ${signal}.`);
      child = null;

      // Stop anything the child left behind.
      signalChildGroup('SIGTERM');

      if (!quitting) {
        console.log('Restarting child in 5s...');
        setTimeout(spawnChild, 5000);
      }
    });
  };

  spawnChild();

  process.on('SIGHUP', () => {
    console.log('Received SIGHUP, reopening log files.');
    reopenLogs();
  });

  // Handle termination signals to quit gracefully.
  const quit = () => {
    console.log('Quitting log-wrapper.');
    quitting = true;

    if (childGroupId == null) {
      process.exit(0);
    }

    // Ask the child and everything it spawned to stop, and give them a moment
    // to do so before forcing them.
    signalChildGroup('SIGTERM');
    const deadline = Date.now() + 1000;
    const poll = setInterval(() => {
      if (childGroupIsEmpty() || Date.now() >= deadline) {
        clearInterval(poll);
        signalChildGroup('SIGKILL');
        process.exit(0);
      }
    }, 100);
  };

  process.once('SIGINT', quit);
  process.once('SIGTERM', quit);

  // When _this_ process stops...
  process.once('exit', () => {
    console.log('Exiting.');

    // Stop the child and anything it spawned, if they're still running.
    signalChildGroup('SIGTERM');
  });
}

main();
