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

  @available(*, deprecated, message: "use backend with a common interface")
  // each agent runs their own server
  var llama: LlamaServer
  var backend: OllamaBackend?

  init(id: String, prompt: String, systemPrompt: String, modelPath: String, contextLength: Int) {
    self.id = id
    self.prompt = prompt
    self.systemPrompt = systemPrompt
    llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
  }

  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(
    speakerId: String, messages: [String], template: Template, temperature: Double?
  ) async throws -> LlamaServer.CompleteResponse {
    if status == .cold {
      status = .coldProcessing
    } else {
      status = .processing
    }

    // TODO: Uncomment this block
    /*
    prompt = template.run(systemPrompt: systemPrompt, messages: messages)

    pendingMessage = ""

    let response = try await llama.complete(
      prompt: prompt, stop: template.stopWords, temperature: temperature
    ) { partialResponse in
      DispatchQueue.main.async {
        self.handleCompletionProgress(partialResponse: partialResponse)
      }
    }

    pendingMessage = response.text
    status = .ready

    return response
     */

    pendingMessage = ""
    for try await partialResponse in try await backend!.complete(messages: messages) {
      self.pendingMessage += partialResponse
      self.prompt = pendingMessage
    }
    status = .ready

    return LlamaServer.CompleteResponse(text: pendingMessage, responseStartSeconds: 0)
  }

  func handleCompletionProgress(partialResponse: String) {
    self.prompt += partialResponse
    self.pendingMessage += partialResponse
  }

  func interrupt() async {
    if status != .processing, status != .coldProcessing { return }
    await llama.interrupt()
    await backend?.interrupt()
  }

  func warmup() async throws {
    if prompt.isEmpty, systemPrompt.isEmpty { return }
    do {
      _ = try await llama.complete(prompt: prompt, stop: nil, temperature: nil)
      status = .ready
    } catch {
      status = .cold
    }
  }
}
