import Foundation
import SwiftUI
import os.lock

actor LlamaServer {

  var modelPath: String?
  var contextLength: Int

  @AppStorage("useGPU") private var useGPU: Bool = DEFAULT_USE_GPU

  private let gpu = GPU.shared
  private var process = Process()
  private var serverUp = false
  private var serverErrorMessage = ""
  private let url = URL(string: "http://127.0.0.1:8690")!

  private var monitor = Process()

  init(modelPath: String, contextLength: Int) {
    self.modelPath = modelPath
    self.contextLength = contextLength
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

  func startServer() async throws {
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
      "--port", "8690",
      "--n-gpu-layers", gpu.available && useGPU ? "4" : "0",
    ]
    print("starting llama.cpp server \(process.arguments!.joined(separator: " "))")

    process.standardInput = FileHandle.nullDevice
    // To debug with server's output, comment these 2 lines to inherit stdout.
    process.standardOutput =  FileHandle.nullDevice
    process.standardError =  FileHandle.nullDevice

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
    if process.isRunning { process.terminate() }
    if monitor.isRunning { monitor.terminate() }
  }

  private func waitForServer() async throws {
    guard process.isRunning else { return }
    serverErrorMessage = ""

    guard let modelPath = self.modelPath else { return }
    let modelName =
      modelPath.split(separator: "/").last?.map { String($0) }.joined() ?? "Unknown model name"

    let serverHealth = ServerHealth()
    await serverHealth.updateURL(url.appendingPathComponent("/health"))
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
