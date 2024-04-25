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

  var systemPrompt = DEFAULT_SYSTEM_PROMPT

  // dialogue is the dialogue from prompt without system prompt / internal thoughts
  @Published var pendingMessage = ""
  @Published var status: Status = .cold

  // each agent runs their own server
  var llama: LlamaServer

  init(id: String, systemPrompt: String, modelPath: String, contextLength: Int) {
    self.id = id
    self.systemPrompt = systemPrompt
    llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
  }

  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(
    speakerId: String, messages: [Message], temperature: Double?
  ) async throws -> LlamaServer.CompleteResponse {
    if status == .cold {
      status = .coldProcessing
    } else {
      status = .processing
    }

    pendingMessage = ""

    let chatMessages = messages.map { m in
      LlamaServer.ChatMessage(
        role: m.fromId == Message.USER_SPEAKER_ID ? .user : .system,
        content: m.text ?? ""
      )
    }
    let response = try await llama.chat(
      messages: chatMessages, temperature: temperature
    ) { partialResponse in
      DispatchQueue.main.async {
        self.handleCompletionProgress(partialResponse: partialResponse)
      }
    }

    pendingMessage = response.text
    status = .ready

    return response
  }

  func handleCompletionProgress(partialResponse: String) {
    self.pendingMessage += partialResponse
  }

  func interrupt() async {
    if status != .processing, status != .coldProcessing { return }
    await llama.interrupt()
  }
}
