@preconcurrency import EventSource
import Foundation
import SwiftUI
import os.lock

func removeUnmatchedTrailingQuote(_ inputString: String) -> String {
  var outputString = inputString
  if inputString.last != "\"" { return outputString }

  // Count the number of quotes in the string
  let countOfQuotes = outputString.reduce(
    0,
    { (count, character) -> Int in
      return character == "\"" ? count + 1 : count
    })

  // If there is an odd number of quotes, remove the last one
  if countOfQuotes % 2 != 0 {
    if let indexOfLastQuote = outputString.lastIndex(of: "\"") {
      outputString.remove(at: indexOfLastQuote)
    }
  }

  return outputString
}

actor LlamaServer {

  var modelPath: String?
  var contextLength: Int

  @AppStorage("useGPU") private var useGPU: Bool = Agent.DEFAULT_USE_GPU

  private let gpu = GPU.shared
  private var process = Process()
  private var outputPipe = Pipe()
  private var serverUp = false
  private var serverErrorMessage = ""
  private var eventSource: EventSource?
  private let host: String
  private let port: String
  private let scheme: String
  private var interrupted = false

  private var monitor = Process()

  init(modelPath: String, contextLength: Int) {
    self.modelPath = modelPath
    self.contextLength = contextLength
    self.scheme = "http"
    self.host = "127.0.0.1"
    self.port = "8690"
  }

  init(contextLength: Int, tls: Bool, host: String, port: String) {
    self.contextLength = contextLength
    self.scheme = tls ? "https" : "http"
    self.host = host
    self.port = port
  }

  private func url(_ path: String) -> URL {
    URL(string: "\(scheme)://\(host):\(port)\(path)")!
  }

  // Start a monitor process that will terminate the server when our app dies.
  private func startAppMonitor(serverPID: pid_t) throws {
    monitor = Process()
    monitor.executableURL = Bundle.main.url(forAuxiliaryExecutable: "server-watchdog")
    monitor.arguments = [String(serverPID)]

    #if DEBUG
      print(
        "starting \(monitor.executableURL!.absoluteString) \(monitor.arguments!.joined(separator: " "))"
      )
    #endif

    let hearbeat = Pipe()
    // write a heartbeat to the pipe every 10 seconds
    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    timer.schedule(deadline: .now(), repeating: 10.0)
    timer.setEventHandler { [weak hearbeat] in
      guard let hearbeat = hearbeat else { return }
      let data = ".".data(using: .utf8) ?? Data()
      hearbeat.fileHandleForWriting.write(data)
    }
    timer.resume()

    monitor.standardInput = hearbeat

    #if !DEBUG
      let monitorOutputPipe = Pipe()
      monitor.standardOutput = monitorOutputPipe
      monitor.standardError = monitorOutputPipe
    #endif

    try monitor.run()

    print("started monitor for \(serverPID)")
  }

  private func startServer() async throws {
    guard !process.isRunning, let modelPath = self.modelPath else { return }
    stopServer()
    process = Process()

    let startTime = DispatchTime.now()

    process.executableURL = Bundle.main.url(forAuxiliaryExecutable: "freechat-server")
    let processes = ProcessInfo.processInfo.activeProcessorCount
    process.arguments = [
      "--model", modelPath,
      "--threads", "\(max(1, Int(ceil(Double(processes) / 3.0 * 2.0))))",
      "--ctx-size", "\(contextLength)",
      "--port", port,
      "--n-gpu-layers", gpu.available && useGPU ? "4" : "0",
    ]

    print("starting llama.cpp server \(process.arguments!.joined(separator: " "))")

    outputPipe = Pipe()
    process.standardInput = Pipe()

    // To debug with server's output, comment these 2 lines to inherit stdout.
    // N.B. this will make readUntilString hang
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    guard
      outputPipe.fileHandleForWriting.fileDescriptor != -1,
      outputPipe.fileHandleForReading.fileDescriptor != -1
    else {
      throw LlamaServerError.pipeFail
    }

    try process.run()

    try await waitForServer()

    try startAppMonitor(serverPID: process.processIdentifier)

    let endTime = DispatchTime.now()
    let elapsedTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000

    #if DEBUG
      print("started server process in \(elapsedTime)ms")
    #endif
  }

  func stopServer() {
    if process.isRunning {
      process.terminate()
    }
    if monitor.isRunning {
      monitor.terminate()
    }
  }

  func complete(
    prompt: String, stop: [String]?, temperature: Double?,
    progressHandler: (@Sendable (String) -> Void)? = nil
  ) async throws -> CompleteResponse {
    dispatchPrecondition(condition: .notOnQueue(.main))
    #if DEBUG
      print("START PROMPT\n \(prompt) \nEND PROMPT\n\n")
    #endif

    let start = CFAbsoluteTimeGetCurrent()
    try await startServer()

    // hit localhost for completion
    var params = CompleteParams(
      prompt: prompt,
      stop: stop ?? [
        "</s>",
        "\n\(Message.USER_SPEAKER_ID):",
        "\n\(Message.USER_SPEAKER_ID.lowercased()):",
        "[/INST]",
        "[INST]",
        "USER:",
      ]
    )
    if let t = temperature { params.temperature = t }

    var request = URLRequest(url: url("/completion"))

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
    var stopResponse: StopResponse?
    listenLoop: for await event in eventSource!.events {
      switch event {
      case .open:
        continue listenLoop
      case .error(let error):
        print("llama.cpp EventSource server error:", error.localizedDescription)
      case .message(let message):
        // parse json in message.data string then print the data.content value and append it to response
        if let data = message.data?.data(using: .utf8) {
          let decoder = JSONDecoder()

          do {
            let responseObj = try decoder.decode(Response.self, from: data)
            let fragment = responseObj.content
            response.append(fragment)
            progressHandler?(fragment)
            if responseDiff == 0 {
              responseDiff = CFAbsoluteTimeGetCurrent() - start
            }

            if responseObj.stop {
              do {
                stopResponse = try decoder.decode(StopResponse.self, from: data)
              } catch {
                print("error decoding stopResponse", error as Any, data)
              }
              #if DEBUG
                print(
                  "server.cpp stopResponse",
                  NSString(data: data, encoding: String.Encoding.utf8.rawValue) ?? "missing")
              #endif
              break listenLoop
            }
          } catch {
            print("error decoding responseObj", error as Any, data)
            break listenLoop
          }
        }
      case .closed:
        print("llama.cpp EventSource closed")
        break listenLoop
      }
    }

    if responseDiff > 0 {
      print("response: \(response)")
      print("\n\n🦙 started response in \(responseDiff) seconds")
    }

    // adding a trailing quote or space is a common mistake with the smaller model output
    let cleanText = removeUnmatchedTrailingQuote(response).trimmingCharacters(
      in: .whitespacesAndNewlines)

    let modelName = stopResponse?.model.split(separator: "/").last?.map { String($0) }.joined()
    return CompleteResponse(
      text: cleanText,
      responseStartSeconds: responseDiff,
      predictedPerSecond: stopResponse?.timings.predicted_per_second,
      modelName: modelName,
      nPredicted: stopResponse?.tokens_predicted
    )
  }

  func interrupt() async {
    if let eventSource, eventSource.readyState != .closed {
      await eventSource.close()
    }
    interrupted = true
  }

  private func waitForServer() async throws {
    guard process.isRunning else { return }
    interrupted = false
    serverErrorMessage = ""

    guard let modelPath = self.modelPath else { return }
    let modelName =
      modelPath.split(separator: "/").last?.map { String($0) }.joined() ?? "Unknown model name"

    let serverHealth = ServerHealth()
    await serverHealth.updateURL(url("/health"))
    await serverHealth.check()

    var timeout = 60
    let tick = 1
    while true {
      await serverHealth.check()
      let score = await serverHealth.score
      if score >= 0.25 { break }
      await serverHealth.check()
      if !process.isRunning {
        throw LlamaServerError.modelError(modelName: modelName)
      }

      try await Task.sleep(for: .seconds(tick))
      timeout -= tick
      if timeout <= 0 {
        throw LlamaServerError.modelError(modelName: modelName)
      }
    }
  }

  struct CompleteResponse {
    var text: String
    var responseStartSeconds: Double
    var predictedPerSecond: Double?
    var modelName: String?
    var nPredicted: Int?
  }

  struct CompleteParams: Codable {
    var prompt: String
    var stop: [String] = ["</s>"]
    var stream = true
    var n_threads = 6

    var n_predict = -1
    var temperature = Agent.DEFAULT_TEMP
    var repeat_last_n = 128  // 0 = disable penalty, -1 = context size
    var repeat_penalty = 1.18  // 1.0 = disabled
    var top_k = 40  // <= 0 to use vocab size
    var top_p = 0.95  // 1.0 = disabled
    var tfs_z = 1.0  // 1.0 = disabled
    var typical_p = 1.0  // 1.0 = disabled
    var presence_penalty = 0.0  // 0.0 = disabled
    var frequency_penalty = 0.0  // 0.0 = disabled
    var mirostat = 0  // 0/1/2
    var mirostat_tau = 5  // target entropy
    var mirostat_eta = 0.1  // learning rate
    var cache_prompt = true

    func toJSON() -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let jsonData = try? encoder.encode(self)
      return String(data: jsonData!, encoding: .utf8)!
    }
  }

  struct Timings: Codable {
    let prompt_n: Int
    let prompt_ms: Double
    let prompt_per_token_ms: Double
    let prompt_per_second: Double?

    let predicted_n: Int
    let predicted_ms: Double
    let predicted_per_token_ms: Double
    let predicted_per_second: Double?
  }

  struct Response: Codable {
    let content: String
    let stop: Bool
  }

  struct StopResponse: Codable {
    let content: String
    let model: String
    let tokens_predicted: Int
    let tokens_evaluated: Int
    let timings: Timings
  }
}

enum LlamaServerError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .modelError(let modelName):
      return "Error Loading (\(modelName))"
    default:
      return "Llama Server Error"
    }
  }

  var recoverySuggestion: String {
    switch self {
    case .modelError:
      return "Try selecting another model in Settings"
    default:
      return "Try again later"
    }
  }

  case pipeFail
  case jsonEncodingError
  case modelError(modelName: String)
}
