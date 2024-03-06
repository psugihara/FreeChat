//
//  LlamaBackend.swift
//  FreeChat
//

import Foundation

actor LlamaBackend: Backend {
  var type: BackendType = .llama
  var baseURL: URL
  var apiKey: String?
  var interrupted = false
  
  private let contextLength: Int

  init(contextLength: Int, baseURL: URL, apiKey: String?) {
    self.contextLength = contextLength
    self.baseURL = baseURL
    self.apiKey = apiKey
  }

  deinit { interrupted = true }

  struct ModelListResponse: Decodable {
    struct Model: Decodable {
      struct Meta: Decodable {
        let nCtxTrain: Int
        let nEmbd: Int
        let nParams: Int
        let nVocab: Int
        let size: Int
        let vocabType: Int
      }
      let id: String
      let created: Int
      let meta: Meta
      let object: String
    }
    let data: [Model]

    static func from(data: Data) throws -> ModelListResponse {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(ModelListResponse.self, from: data)
    }
  }

  nonisolated func listModels() async throws -> [String] {
    let url = await baseURL.appendingPathComponent("/v1/models")
    let (data, _) = try await URLSession.shared.data(from: url)
    return try ModelListResponse.from(data: data).data.compactMap({ $0.id.components(separatedBy: "/").last })
  }
}
