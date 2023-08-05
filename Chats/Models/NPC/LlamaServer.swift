import EventSource
import Foundation

class LlamaServer {
  private var process = Process()
  private var outputPipe = Pipe()
  private var eventSource: EventSource?
  
  private var monitor = Process()

  deinit {
    if process.isRunning {
      process.terminate()
    }
  }
  
  // Start a monitor process that will terminate the server when our app dies.
  private func startMonitor(serverPID: pid_t) throws {
    HeartbeatManager.shared.startHeartbeat()
    
    monitor = Process()
    monitor.executableURL = Bundle.main.url(forAuxiliaryExecutable: "server-watchdog")
    monitor.arguments = [HeartbeatManager.shared.fileURL().path, String(serverPID)]
    
#if DEBUG
    print("starting \(monitor.executableURL!.absoluteString) \(monitor.arguments!.joined(separator: " "))")
#endif

    monitor.standardInput = Pipe()

#if !DEBUG
    let monitorOutputPipe = Pipe()
    monitor.standardOutput = monitorOutputPipe
    monitor.standardError = monitorOutputPipe
#endif

    try monitor.run()

    print("started monitor for \(serverPID)")
  }
  
  private func startServer() throws {
    if process.isRunning { return }
    process = Process()
    
    let startTime = DispatchTime.now()
    
    print("starting llama.cpp server")
    process.executableURL = Bundle.main.url(forResource: "server", withExtension: "")
    let modelURL = Bundle.main.url(forResource: "llama-2-7b-chat.ggmlv3.q4_1", withExtension: ".bin")!
    let processes = ProcessInfo.processInfo.activeProcessorCount
    process.arguments = [
      "--model", modelURL.path,
      "--threads", "\(max(1, ceil(Double(processes) / 2.0)))",
      "--rope-freq-scale", "1.0",
      "--ctx-size", "4096",
      "--rms-norm-eps", "1e-5",
    ]
    
    outputPipe = Pipe()
    process.standardInput = Pipe()  // fails without this being set!
    
#if !DEBUG
    process.standardOutput = outputPipe
    process.standardError = outputPipe
#endif
    
    guard
      outputPipe.fileHandleForWriting.fileDescriptor != -1,
      outputPipe.fileHandleForReading.fileDescriptor != -1
    else {
      throw LlamaServerError.pipeFail
    }
    
    try process.run()
    try startMonitor(serverPID: process.processIdentifier)
    
    let endTime = DispatchTime.now()
    let elapsedTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
    
#if DEBUG
    print("started server process in \(elapsedTime)ms")
#endif
  }
  
  func stopServer() {
    process.terminate()
  }
  
  func complete(prompt: String, progressHandler: ((String) -> Void)? = nil) async throws -> String {
#if DEBUG
     print("START PROMPT\n \(prompt) \nEND PROMPT\n\n")
#endif
    
    try startServer()
    
    let start = CFAbsoluteTimeGetCurrent()
    // hit localhost for completion
    let params = CompleteParams(
      prompt: prompt,
      stop: ["</s>",
             "\n\(Message.USER_SPEAKER_ID):",
             "\n\(Message.USER_SPEAKER_ID.capitalized):"
            ]
    )
    
    let url = URL(string: "http://127.0.0.1:8080/completion")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.httpBody = params.toJSON().data(using: .utf8)
    
    // Use EventSource to receive server sent events
    eventSource = EventSource(request: request)
    
    eventSource!.connect()
    
    var response = ""
    var responseDiff = 0.0
    listenLoop: for await event in eventSource!.events {
      switch event {
        case .open:
          continue
        case .error(let error):
          print("llama.cpp server error:", error.localizedDescription)
        case .message(let message):
          // parse json in message.data string then print the data.content value and append it to response
          if let data = message.data?.data(using: .utf8) {
            let decoder = JSONDecoder()
            let responseObj = try decoder.decode(CompleteResponse.self, from: data)
            let fragment = responseObj.content
            response.append(fragment)
            progressHandler?(fragment)
            responseDiff = CFAbsoluteTimeGetCurrent() - start
            
            if responseObj.stop {
              break listenLoop
            }
          }
        case .closed:
          break
      }
    }
    
    
    if responseDiff > 0 {
      print("response: \(response)")
      print("\n\n🦙 started response in \(responseDiff) seconds")
    }
    
    return response
  }
  
  struct CompleteParams: Codable {
    var prompt: String
    var stop: [String] = ["</s>"]
    var stream = true
    var n_threads = 6
    
    var n_predict = 700
    var temperature = 0.2
    var repeat_last_n = 256  // 0 = disable penalty, -1 = context size
    var repeat_penalty = 1.18  // 1.0 = disabled
    var top_k = 40  // <= 0 to use vocab size
    var top_p = 0.5  // 1.0 = disabled
    var tfs_z = 1.0  // 1.0 = disabled
    var typical_p = 1.0  // 1.0 = disabled
    var presence_penalty = 0.0  // 0.0 = disabled
    var frequency_penalty = 0.0  // 0.0 = disabled
    var mirostat = 0  // 0/1/2
    var mirostat_tau = 5  // target entropy
    var mirostat_eta = 0.1  // learning rate
    
    func toJSON() -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let jsonData = try? encoder.encode(self)
      return String(data: jsonData!, encoding: .utf8)!
    }
  }
  
  struct CompleteResponse: Codable {
    let content: String
    let stop: Bool
  }
}

enum LlamaServerError: Error {
  case pipeFail
  case jsonEncodingError
}
