import Foundation

class HeartbeatManager {
  // Singleton instance
  static let shared = HeartbeatManager()
  

  func fileURL() -> URL {
    guard let documentsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      fatalError("Unable to retrieve the Documents directory.")
    }
    
    // Append the filename to the "Application Support" directory to create the fileURL for the heartbeat file
    return documentsDirectory.appendingPathComponent("heartbeatfile.txt")
  }
  
  // Flag to track if the heartbeat has started
  private var heartbeatStarted = false
  
  // Private initializer to enforce singleton pattern
  private init() {}
  
  // Function to create the heartbeat file
  private func createHeartbeatFile() {
    let success = FileManager.default.createFile(atPath: fileURL().path, contents: nil, attributes: nil)
    if !success {
      print("could not create heartbeat file at path \(fileURL().path)")
    }
  }
  
  // Function to remove the heartbeat file
  private func removeHeartbeatFile() {
    do {
      try FileManager.default.removeItem(at: fileURL())
    } catch {
      print("Error removing heartbeat file: \(error)")
    }
  }
  
  // Function to periodically update the heartbeat file (e.g., every 10 seconds)
  private func updateHeartbeatFile() {
    createHeartbeatFile()
    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
      self.updateHeartbeatFile()
    }
  }
  
  // Call this function when your app is ready to start the heartbeat
  func startHeartbeat() {
    // Check if the heartbeat has already started
    guard !heartbeatStarted else {
      return
    }
    
    // Start updating the heartbeat file
    updateHeartbeatFile()
    
    // Set the flag to indicate that the heartbeat has started
    heartbeatStarted = true
  }
  
  // Call this function to stop the heartbeat (e.g., when the app is about to terminate forcefully)
  func stopHeartbeat() {
    removeHeartbeatFile()
  }
}
