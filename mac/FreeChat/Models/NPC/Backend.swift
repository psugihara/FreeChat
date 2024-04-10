//
//  Backend.swift
//  FreeChat
//

import Foundation
import EventSource

protocol Backend: Actor, Sendable {
  var type: BackendType { get }
  var baseURL: URL { get }
  var apiKey: String? { get }
  var interrupted: Bool { get set }

  func complete(params: CompleteParams) async throws -> AsyncStream<String>
  func buildRequest(path: String, params: CompleteParams) -> URLRequest
  func interrupt() async

  func listModels() async throws -> [String]
}

extension Backend {
  func complete(params: CompleteParams) async throws -> AsyncStream<String> {
    let request = buildRequest(path: "/v1/chat/completions", params: params)
    self.interrupted = false

    return AsyncStream<String> { continuation in
      Task.detached {
        let eventSource = EventSource()
        let dataTask = eventSource.dataTask(for: request)
      L: for await event in dataTask.events() {
        guard await !self.interrupted else { break L }
        switch event {
        case .open: continue
        case .error(let error):
          print("EventSource server error:", error.localizedDescription)
          break L
        case .message(let message):
          if let response = try CompleteResponse.from(data: message.data?.data(using: .utf8)),
             let choice = response.choices.first {
            if let content = choice.delta.content?.trimTrailingQuote() { continuation.yield(content) }
            if choice.finishReason != nil { break L }
          }
        case .closed: break L
        }
      }

        continuation.finish()
      }
    }
  }

  func interrupt() async { interrupted = true }

  func buildRequest(path: String, params: CompleteParams) -> URLRequest {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("Bearer: \(apiKey ?? "none")", forHTTPHeaderField: "Authorization")
    request.httpBody = params.toJSON().data(using: .utf8)

    return request
  }
}
  
enum BackendType: String, CaseIterable {
  case local = "This Computer (default)"
  case llama = "Llama.cpp"
  case openai = "OpenAI"
  case ollama = "Ollama"

  var defaultURL: URL {
    switch self {
    case .local: return URL(string: "http://127.0.0.1:8690")!
    case .llama: return URL(string: "http://127.0.0.1:8690")!
    case .ollama: return URL(string: "http://127.0.0.1:11434")!
    case .openai: return URL(string: "https://api.openai.com:443")!
    }
  }

  var howtoConfigure: AttributedString {
    switch self {
    case .local: try! AttributedString(markdown: NSLocalizedString("Runs on this computer offline using llama.cpp. No configuration required", comment: "No configuration"))
    case .llama: try! AttributedString(markdown: NSLocalizedString("Llama.cpp is an efficient server than runs more than just LLaMa models. [Learn more](https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md)", comment: "What it is and Usage link"))
    case .openai: try! AttributedString(markdown: NSLocalizedString("Configure OpenAI's ChatGPT. [Learn more](https://openai.com/product)", comment: "What it is and Usage link"))
    case .ollama: try! AttributedString(markdown: NSLocalizedString("Ollama runs large language models locally. [Learn more](https://ollama.com)", comment: "What it is and Usage link"))
    }
  }
}

struct RoleMessage: Codable {
  let role: String?
  let content: String?
}

struct CompleteParams: Encodable {
  enum Mirostat: Int, Encodable {
    case disabled = 0
    case v1 = 1
    case v2 = 2
  }
  let messages: [RoleMessage]
  let model: String
  let mirostat: Mirostat = .disabled
  let mirostatETA: Float = 0.1
  let mirostatTAU: Float = 5
  let numCTX: Int // 2048
  let numGQA = 1
  let numGPU: Int? = nil
  let numThread: Int? = nil
  let repeatLastN = 64
  let repeatPenalty: Float = 1.1
  let temperature: Float // 0.7
  let seed: Int? = nil
  let stop: [String]? = nil
  let tfsZ: Float? = nil
  let numPredict = 128
  let topK = 40
  let topP: Float = 0.9
  let template: String? = nil
  let cachePrompt = true
  let stream = true
  let keepAlive = true

  func toJSON() -> String {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let jsonData = try? encoder.encode(self)
    return String(data: jsonData!, encoding: .utf8)!
  }
}

struct CompleteResponse: Decodable {
  struct Choice: Decodable {
    let index: Int
    let delta: RoleMessage
    let finishReason: String?
  }
  let id: String
  let object: String
  let created: Int
  let model: String
  let systemFingerprint: String?
  let choices: [Choice]

  static func from(data: Data?) throws -> CompleteResponse? {
    guard let data else { return nil }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(CompleteResponse.self, from: data)
  }
}

struct CompleteResponseSummary {
    var text: String
    var responseStartSeconds: Double
    var predictedPerSecond: Double?
    var modelName: String?
    var nPredicted: Int?
  }
