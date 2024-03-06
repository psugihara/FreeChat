//
//  OpenAIBackend.swift
//  FreeChat
//

import Foundation

actor OpenAIBackend: Backend {
  var type: BackendType = .openai
  let baseURL: URL
  let apiKey: String?
  var interrupted: Bool = false
  
  private let contextLength: Int

  init(contextLength: Int, baseURL: URL, apiKey: String?) {
    self.contextLength = contextLength
    self.baseURL = baseURL
    self.apiKey = apiKey
  }

  deinit { interrupted = true }

  nonisolated func listModels() -> [String] {
    [
      "gpt-4-0125-preview",
      "gpt-4-turbo-preview",
      "gpt-4-1106-preview",
      "gpt-4-vision-preview",
      "gpt-4-1106-vision-preview",
      "gpt-4",
      "gpt-4-0613",
      "gpt-4-32k",
      "gpt-4-32k-0613",
      "gpt-3.5-turbo-0125",
      "gpt-3.5-turbo",
      "gpt-3.5-turbo-1106",
      "gpt-3.5-turbo-instruct",
      "gpt-3.5-turbo-16k",
      "gpt-3.5-turbo-0613",
      "gpt-3.5-turbo-16k-0613",
      "babbage-002",
      "davinci-002",
    ]
  }
}
