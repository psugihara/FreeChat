import Foundation

class Agent: ObservableObject {
  static let DEFAULT_SYSTEM_PROMPT = """
    You are a helpful and honest assistant. Always answer in the most accurate way possible.
    """
  
  enum Status {
    case processing
    case ready
  }
  
  var id: String
  
  // prompt is the actual running prompt with the llm
  var prompt = ""
  var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  
  // dialogue is the dialogue from prompt without system prompt / internal thoughts
  @Published var pendingMessage = ""
  @Published var status: Status = .ready
  
  // each agent runs their own server
  let llama = LlamaServer()
  
  init(id: String, prompt: String, systemPrompt: String, modelPath: String) {
    self.id = id
    self.prompt = prompt
    self.systemPrompt = systemPrompt
    if modelPath != "" { llama.modelPath = modelPath }
  }
  
  // this is the main loop of the agent
  // listen -> respond -> update mental model and save checkpoint
  // we respond before updating to avoid a long delay after user input
  func listenThinkRespond(speakerId: String, message: String) async -> String {
    await MainActor.run {
      status = .processing
    }
    
    // The llama 2 prompt format seems to work fine across models.
    if prompt == "" {
      prompt = """
        <s>[INST] <<SYS>>
        \(systemPrompt)
        <</SYS>>
        
        \(Message.USER_SPEAKER_ID): hi [/INST] ### Assistant: hello</s>
        """
    }
    if !prompt.hasSuffix("</s>") {
      prompt += "</s>"
    }
    
    if prompt.suffix(2000).contains(systemPrompt) {
      prompt += "<s>[INST]\(Message.USER_SPEAKER_ID): \(message)[/INST] ### Assistant:"
    } else {
      // if the system prompt hasn't been covered in a while, pepper it in
      prompt += """
        <s>[INST] <<SYS>>
        \(systemPrompt)
        <<SYS>>
        
        \(Message.USER_SPEAKER_ID): \(message)[/INST] ### Assistant:
        """
    }
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
  
  func interrupt() async  {
    if status != .processing { return }
    await llama.interrupt()
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
