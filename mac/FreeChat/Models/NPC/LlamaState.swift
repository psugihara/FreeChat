import Foundation

@MainActor
class LlamaState: ObservableObject {
  @Published var messageLog = ""

  var modelPath: String
  var contextLength: Int

  private var llamaContext: LlamaContext?
  private var defaultModelUrl: URL? {
    Bundle.main.url(forResource: "ggml-model", withExtension: "gguf", subdirectory: "models")
    // Bundle.main.url(forResource: "llama-2-7b-chat", withExtension: "Q2_K.gguf", subdirectory: "models")
  }

  init(modelPath: String, contextLength: Int) {
    self.modelPath = modelPath
    self.contextLength = contextLength

    do {
      try loadModel(modelUrl: defaultModelUrl)
    } catch {
      messageLog += "Error!\n"
    }
  }

  func loadModel(modelUrl: URL?) throws {
    messageLog += "Loading model...\n"
    if let modelUrl {
      llamaContext = try LlamaContext.create_context(
        path: modelUrl.path(), n_ctx: UInt32(contextLength))
      messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
    } else {
      messageLog += "Could not locate model\n"
    }
  }

  func complete(
    prompt: String, stop: [String]?, temperature: Double?,
    progressHandler: (@Sendable (String) -> Void)? = nil
  ) async {
    guard let llamaContext else {
      return
    }

    await llamaContext.completion_init(text: prompt)
    messageLog += "\(prompt)"

    while await llamaContext.n_cur <= llamaContext.n_len {
      let result = await llamaContext.completion_loop()
      messageLog += "\(result)"
    }
    await llamaContext.clear()
    messageLog += "\n\ndone\n"
  }

  func clear() async {
    guard let llamaContext else {
      return
    }

    await llamaContext.clear()
    messageLog = ""
  }

  func interrupt() async {
    print("SHOULD INTERRUPT")
  }
}
