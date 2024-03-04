//
//  OpenAIBackend.swift
//  FreeChat
//

import Foundation
import EventSource

actor OpenAIBackend {

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
      case .openai: return URL(string: "https://api.openai.com")!
      }
    }
  }

  struct RoleMessage: Codable {
    let role: String
    let content: String
  }
  
  struct CompleteParams: Encodable {
    struct OllamaOptions: Encodable {
      enum Mirostat: Int, Encodable {
        case disabled = 0
        case v1 = 1
        case v2 = 2
      }
      let mirostat: Mirostat
      let mirostatETA: Float = 0.1
      let mirostatTAU: Float = 5
      let numCTX = 2048
      let numGQA = 1
      let numGPU: Int? = nil
      let numThread: Int? = nil
      let repeatLastN = 64
      let repeatPenalty: Float = 1.1
      let temperature: Float = 0.7
      let seed: Int? = nil
      let stop: String? = nil
      let tfsZ: Float? = nil
      let numPredict = 128
      let topK = 40
      let topP: Float = 0.9
    }
    let messages: [RoleMessage]
    let model: String
    let format: String? = nil
    let options: OllamaOptions? = nil
    let template: String? = nil
    let stream = true
    let keepAlive = true

    func toJSON() -> String {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      let jsonData = try? encoder.encode(self)
      return String(data: jsonData!, encoding: .utf8)!
    }
  }

  struct Response: Decodable {
    struct Choice: Decodable {
      let index: Int
      let delta: RoleMessage
      let finishReason: String?
    }
    let id: String
    let object: String
    let created: Int
    let model: String
    let systemFingerprint: String
    let choices: [Choice]

    static func from(data: Data?) throws -> Response? {
      guard let data else { return nil }
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(Response.self, from: data)
    }
  }

  struct ResponseSummary {
    var text: String
    var responseStartSeconds: Double
    var predictedPerSecond: Double?
    var modelName: String?
    var nPredicted: Int?
  }

  private var interrupted = false

  private let contextLength: Int
  private let baseURL: URL
  private let backendType: BackendType

  init(backend: BackendType, contextLength: Int, tls: Bool, host: String, port: String) {
    self.contextLength = contextLength
    self.baseURL = URL(string: "\(tls ? "https" : "http")://\(host):\(port)")!
    self.backendType = backend
  }

  func complete(messages: [String]) throws -> AsyncStream<String> {
    let messages = [RoleMessage(role: "system", content: "you know")]
      + messages.map({ RoleMessage(role: "user", content: $0) })
    let params = CompleteParams(messages: messages, model: "orca-mini")
    let url = baseURL.appendingPathComponent("/v1/chat/completions")
    let request = buildRequest(url: url, params: params)
    interrupted = false

    return AsyncStream<String> { continuation in
      Task.detached {
        let eventSource = EventSource()
        let dataTask = eventSource.dataTask(for: request)

      L: for await event in dataTask.events() {
          guard await !self.interrupted else { break L }
          switch event {
          case .open: continue
          case .error(let error):
            print("ollama EventSource server error:", error.localizedDescription)
            break L
          case .message(let message):
            if let response = try Response.from(data: message.data?.data(using: .utf8)),
            let choice = response.choices.first {
              continuation.yield(choice.delta.content)
              if choice.finishReason != nil { break L }
            }
          case .closed:
            print("ollama EventSource closed")
            break L
          }
        }

        continuation.finish()
      }
    }
  }

  func interrupt() { interrupted = true }

  func buildRequest(url: URL, params: CompleteParams, token: String = "none") -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("Bearer: \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = params.toJSON().data(using: .utf8)

    return request
  }

  //  MARK: - List models

  struct TagsResponse: Decodable {
    struct Model: Decodable {
      struct Details: Decodable {
        let parentModel: String?
        let format: String
        let family: String
        let families: [String]?
        let parameterSize: String
        let quantizationLevel: String
      }
      let name: String
      let model: String
      let modifiedAt: String
      let size: Int
      let digest: String
      let details: Details
    }
    let models: [Model]

    static func from(data: Data) throws -> TagsResponse {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(TagsResponse.self, from: data)
    }
  }

  nonisolated func fetchOllamaModels() async throws -> TagsResponse {
    let url = baseURL.appendingPathComponent("/api/tags")
    let (data, _) = try await URLSession.shared.data(from: url)
    return try TagsResponse.from(data: data)
  }
}
