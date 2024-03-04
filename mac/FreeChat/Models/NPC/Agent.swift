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
  private var backend: OpenAIBackend!

  init(id: String, prompt: String, systemPrompt: String, modelPath: String, contextLength: Int) {
    self.id = id
    self.prompt = prompt
    self.systemPrompt = systemPrompt
    llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
  }

  func createBackend(contextLength: Int, tls: Bool, host: String, port: String) {
    self.backend = OpenAIBackend(backend: .ollama, contextLength: contextLength, tls: tls, host: host, port: port)
  }

  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(
    speakerId: String, messages: [String], template: Template, temperature: Double?
  ) async throws -> OpenAIBackend.ResponseSummary {
    status = status == .cold ? .coldProcessing : .processing
    pendingMessage = ""
    for try await partialResponse in try await backend!.complete(messages: messages) {
      self.pendingMessage += partialResponse
      self.prompt = pendingMessage
    }
    status = .ready

    return OpenAIBackend.ResponseSummary(text: pendingMessage, responseStartSeconds: 0)
  }

  func handleCompletionProgress(partialResponse: String) {
    self.prompt += partialResponse
    self.pendingMessage += partialResponse
  }

  func interrupt() async {
    if status != .processing, status != .coldProcessing { return }
    await backend?.interrupt()
  }

  func warmup() async throws {
    if prompt.isEmpty, systemPrompt.isEmpty { return }
    // TODO: Implement this part
    /*
    do {
      _ = try await llama.complete(prompt: prompt, stop: nil, temperature: nil)
      status = .ready
    } catch {
      status = .cold
    }
     */
  }
}
