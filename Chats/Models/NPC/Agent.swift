import Foundation

class Agent: ObservableObject {
  enum Status {
    case processing
    case ready
  }
  
  var id: String
  
  // prompt is the actual running prompt with the llm
  var prompt = ""
  
  // dialogue is the dialogue from prompt without system prompt / internal thoughts
  @Published var pendingMessage = ""
  @Published var status: Status = .ready
  
  // each agent runs their own server
  let llama = LlamaServer()
  
  init(id: String, prompt: String) {
    self.id = id
    self.prompt = prompt
  }
  
  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(speakerId: String, message: String) async -> String {
    await MainActor.run {
      status = .processing
    }
    
    if prompt == "" {
      prompt = systemPrompt()
    }
    prompt += "\n\(Message.USER_SPEAKER_ID): \(message)\n"
    prompt += "\(id): "
    await MainActor.run {
      self.pendingMessage = ""
    }
    let response = try! await llama.complete(prompt: prompt) { response in
      self.prompt += response
      DispatchQueue.main.sync {
        self.pendingMessage += response
      }
    }
    
    await MainActor.run {
      status = .ready
    }
    
    return response
  }
  
  func systemPrompt() -> String {
    return """
      Simulate a professional conversation between \(Message.USER_SPEAKER_ID) and an assistant, \(id).
      The assistant is concise, helpful, and formats responses as markdown.
      """
  }
  
  func warmup() async {
    if prompt == "" { return }
    do {
      _ = try await llama.complete(prompt: prompt)
    } catch {
      print("failed to warmup llama: \(error.localizedDescription)")
    }
  }
}
