import Foundation

@MainActor
class Agent: ObservableObject {
  enum Status {
    case cold
    case coldProcessing
    case ready  // warmed up
    case processing
  }

  var id: String

  // prompt is the actual running prompt with the llm
  var prompt = ""
  var systemPrompt = DEFAULT_SYSTEM_PROMPT

  // dialogue is the dialogue from prompt without system prompt / internal thoughts
  @Published var pendingMessage = ""
  @Published var status: Status = .cold

  // each agent runs their own server
  var llama: LlamaServer
  private var backend: Backend

  init(id: String, prompt: String, systemPrompt: String, modelPath: String, contextLength: Int) {
    self.id = id
    self.prompt = prompt
    self.systemPrompt = systemPrompt
    self.llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
    self.backend = LocalBackend(baseURL: BackendType.local.defaultURL, apiKey: nil)
  }

  func createBackend(_ backend: BackendType, contextLength: Int, config: BackendConfig) {
    let baseURL = config.baseURL ?? backend.defaultURL

    switch backend {
    case .local:
      self.backend = LocalBackend(baseURL: baseURL, apiKey: config.apiKey)
    case .llama:
      self.backend = LlamaBackend(baseURL: baseURL, apiKey: config.apiKey)
    case .openai:
      self.backend = OpenAIBackend(baseURL: baseURL, apiKey: config.apiKey)
    case .ollama:
      self.backend = OllamaBackend(baseURL: baseURL, apiKey: config.apiKey)
    }
  }

  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(speakerId: String, params: CompleteParams) async throws -> CompleteResponseSummary {
    status = status == .cold ? .coldProcessing : .processing
    pendingMessage = ""
    for try await partialResponse in try await backend.complete(params: params) {
      self.pendingMessage += partialResponse
      self.prompt = pendingMessage
    }
    status = .ready

    return CompleteResponseSummary(text: pendingMessage, responseStartSeconds: 0)
  }

  func handleCompletionProgress(partialResponse: String) {
    self.prompt += partialResponse
    self.pendingMessage += partialResponse
  }

  func interrupt() async {
    if status != .processing, status != .coldProcessing { return }
    await backend.interrupt()
  }

  func warmup() async throws {
    if prompt.isEmpty, systemPrompt.isEmpty { return }
    do {
      _ = try await backend.complete(params: CompleteParams(messages: [], model: "", numCTX: 2048, temperature: 0.7))
      status = .ready
    } catch {
      status = .cold
    }
  }
}
