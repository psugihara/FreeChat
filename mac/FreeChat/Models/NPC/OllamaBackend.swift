//
//  OllamaBackend.swift
//  FreeChat
//

import Foundation

actor OllamaBackend: Backend {
  var type: BackendType = .ollama
  var baseURL: URL
  var apiKey: String?
  var interrupted = false

  init(baseURL: URL, apiKey: String?) {
    self.baseURL = baseURL
    self.apiKey = apiKey
  }

  deinit { interrupted = true }
  
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

  nonisolated func listModels() async throws -> [String] {
    let url = await baseURL.appendingPathComponent("/api/tags")
    let (data, _) = try await URLSession.shared.data(from: url)
    return try TagsResponse.from(data: data).models.map({ $0.name })
  }
}
