import Foundation

func log(_ line: String) {
  print("[watchdog]", line)
}

// Function to terminate the server process (replace this with your actual termination logic)
func terminateServerProcess(pid: Int32) {
  log("Terminating the server process with PID \(pid).")
  kill(pid, SIGTERM)
  log("exiting")
  exit(0)
}

// Function to check the existence of the heartbeat file and detect if the main app is still alive
func checkHeartbeatFile(heartbeatFilePath: String, serverProcessPID: Int32) {
  // Adjust the time interval based on how frequently you want to check the heartbeat file
  let checkInterval: TimeInterval = 10.0 // seconds

  while true {
    let fileManager = FileManager.default

    if let attributes = try? fileManager.attributesOfItem(atPath: heartbeatFilePath),
       let modificationDate = attributes[.modificationDate] as? Date {
      // Get the time interval between the modification date and the current time
      let timeIntervalSinceModification = Date().timeIntervalSince(modificationDate)
      if timeIntervalSinceModification > 20 {
        // If the file is older than 20 seconds, consider the main app unresponsive
        log("Main app is not responding (heartbeat file is stale). Terminating the server process.")
        terminateServerProcess(pid: serverProcessPID)
      } else {
        // If the file is recent, the main app is running; continue checking
        log("Main app is alive. Last heartbeat: \(timeIntervalSinceModification)s")
      }
    } else {
      terminateServerProcess(pid: serverProcessPID)
      // Failed to get the file attributes, log an error (this will happen when the file doesn't exist)
      log("Error: Unable to get attributes of the heartbeat file.")
    }

    // Wait for the next check interval before checking again
    Thread.sleep(forTimeInterval: checkInterval)
  }
}

// Start the watchdog process
func startWatchdog() {
  guard CommandLine.arguments.count == 3 else {
    print("usage: server-watchdog <heartbeat_file_path> <pid_to_kill>")
    return
  }

  let heartbeatFilePath = CommandLine.arguments[1].removingPercentEncoding!
  guard let serverProcessPID = Int32(CommandLine.arguments[2]) else {
    log("Error: Invalid server process PID.")
    return
  }

  log("Watchdog process started.")
  checkHeartbeatFile(heartbeatFilePath: heartbeatFilePath, serverProcessPID: serverProcessPID)
}



// Call the function to start the watchdog process
startWatchdog()
