//
//  ConversationView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import MarkdownUI
import Foundation

struct ConversationView: View, Sendable {
  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject private var conversationManager: ConversationManager

  @AppStorage("backendTypeID") private var backendTypeID: String?
  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("systemPrompt") private var systemPrompt: String = DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength: Int = DEFAULT_CONTEXT_LENGTH
  @AppStorage("playSoundEffects") private var playSoundEffects = true
  @AppStorage("useGPU") private var useGPU: Bool = DEFAULT_USE_GPU
  @AppStorage("temperature") private var temperature: Double = DEFAULT_TEMP

  private static let SEND = NSDataAsset(name: "ESM_Perfect_App_Button_2_Organic_Simple_Classic_Game_Click")
  private static let PING = NSDataAsset(name: "ESM_POWER_ON_SYNTH")
  let sendSound = NSSound(data: SEND!.data)
  let receiveSound = NSSound(data: PING!.data)

  var conversation: Conversation {
    conversationManager.currentConversation
  }

  var agent: Agent {
    conversationManager.agent
  }

  @State var pendingMessage: Message?

  @State var messages: [Message] = []

  @State var showUserMessage = true
  @State var showResponse = true
  @State private var scrollPositions = [String: CGFloat]()
  @State var pendingMessageText = ""

  @State var scrollOffset = CGFloat.zero
  @State var scrollHeight = CGFloat.zero
  @State var autoScrollOffset = CGFloat.zero
  @State var autoScrollHeight = CGFloat.zero

  @State var llamaError: LlamaServerError? = nil
  @State var showErrorAlert = false

  var body: some View {
    ObservableScrollView(scrollOffset: $scrollOffset, scrollHeight: $scrollHeight) { proxy in
      VStack(alignment: .leading) {
        ForEach(messages) { m in
          if m == messages.last! {
            if m == pendingMessage {
              MessageView(pendingMessage!, overrideText: pendingMessageText, agentStatus: agent.status)
                .onAppear {
                  scrollToLastIfRecent(proxy)
                }
                .opacity(showResponse ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 170, damping: 20), value: showResponse)
                .id("\(m.id)\(m.updatedAt as Date?)")
            } else {
              MessageView(m, agentStatus: nil)
                .id("\(m.id)\(m.updatedAt as Date?)")
                .opacity(showUserMessage ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 170, damping: 20), value: showUserMessage)
            }
          } else {
            MessageView(m, agentStatus: nil).transition(.identity).id("\(m.id)\(m.updatedAt as Date?)")
          }
        }
      }
      .padding(.vertical, 12)
      .onReceive(
        agent.$pendingMessage.throttle(for: .seconds(0.1), scheduler: RunLoop.main, latest: true)
      ) { text in
        pendingMessageText = text
      }
      .onReceive(
        agent.$pendingMessage.throttle(for: .seconds(0.2), scheduler: RunLoop.main, latest: true)
      ) { _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          autoScroll(proxy)
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("backendTypeIDDidChange"))) { _ in
        initializeBackends()
      }
    }
    .textSelection(.enabled)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      MessageTextField { s in
        Task {
          await submit(s)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .onAppear { showConversation(conversation) }
    .onChange(of: conversation) { nextConvo in showConversation(nextConvo) }
    .onChange(of: selectedModelId) { showConversation(conversation, modelId: $0) }
    .navigationTitle(conversation.titleWithDefault)
    .alert(isPresented: $showErrorAlert, error: llamaError) { _ in
      Button("OK") {
        llamaError = nil
      }
    } message: { error in
      Text(error.recoverySuggestion ?? "")
    }
    .background(Color.textBackground)
  }

  private func playSendSound() {
    guard let sendSound, playSoundEffects else { return }
    sendSound.volume = 0.3
    sendSound.play()
  }

  private func playReceiveSound() {
    guard let receiveSound, playSoundEffects else { return }
    receiveSound.volume = 0.5
    receiveSound.play()
  }

  private func showConversation(_ c: Conversation, modelId: String? = nil) {
    messages = c.orderedMessages
    initializeBackends()
  }

  private func initializeBackends() {
    let backendType: BackendType = BackendType(rawValue: backendTypeID ?? "") ?? .local
    if backendType == .local {
      Task { try? await initializeBackendLocal() }
    }
    
    do {
      let config = try fetchBackendConfig(context: viewContext) ?? BackendConfig(context: viewContext)
      agent.createBackend(backendType, contextLength: contextLength, config: config)

    } catch { print("error fetching backend config", error) }
  }

  private func initializeBackendLocal() async throws {
    guard let selectedModelId, !selectedModelId.isEmpty,
    let id = UUID(uuidString: selectedModelId)
    else { return }
    
    let llamaPath = await agent.llama.modelPath
    let req = Model.fetchRequest()
    req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    guard let model = try viewContext.fetch(req).first,
       let modelPath = model.url?.path(percentEncoded: false),
          modelPath != llamaPath
    else { return }
    
    await agent.llama.stopServer()
    agent.llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
  }

  private func scrollToLastIfRecent(_ proxy: ScrollViewProxy) {
    let fiveSecondsAgo = Date() - TimeInterval(5) // 5 seconds ago
    let last = messages.last
    if last?.updatedAt != nil, last!.updatedAt! >= fiveSecondsAgo {
      proxy.scrollTo(last!.id, anchor: .bottom)
    }
  }

  // autoscroll to the bottom if the user is near the bottom
  private func autoScroll(_ proxy: ScrollViewProxy) {
    let last = messages.last
    if last != nil, shouldAutoScroll() {
      proxy.scrollTo(last!.id, anchor: .bottom)
      engageAutoScroll()
    }
  }

  private func shouldAutoScroll() -> Bool {
    scrollOffset >= autoScrollOffset - 40 && scrollHeight > autoScrollHeight
  }

  private func engageAutoScroll() {
    autoScrollOffset = scrollOffset
    autoScrollHeight = scrollHeight
  }

  @MainActor
  func handleResponseError(_ e: LlamaServerError) {
    print("handle response error", e.localizedDescription)
    if let m = pendingMessage {
      viewContext.delete(m)
    }
    llamaError = e
    showResponse = false
    showErrorAlert = true
  }

  func submit(_ input: String) async {
    if (agent.status == .processing || agent.status == .coldProcessing) {
      await agent.interrupt()
    }

    playSendSound()
    showUserMessage = false
    engageAutoScroll()

    // Create user's message
    do {
      _ = try Message.create(text: input, fromId: Message.USER_SPEAKER_ID, conversation: conversation, systemPrompt: systemPrompt, inContext: viewContext)
    } catch (let error) {
      print("Error creating message", error.localizedDescription)
    }
    showResponse = false

    let agentConversation = conversation
    messages = agentConversation.orderedMessages
    withAnimation {
      showUserMessage = true
    }

    // Pending message for bot's reply
    let m = Message(context: viewContext)
    m.fromId = agent.id
    m.createdAt = Date()
    m.updatedAt = m.createdAt
    m.systemPrompt = systemPrompt
    m.text = ""
    pendingMessage = m

    agent.systemPrompt = systemPrompt

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      guard agentConversation == conversation,
        !m.isDeleted,
        m.managedObjectContext == agentConversation.managedObjectContext else {
        return
      }

      m.conversation = agentConversation
      messages = agentConversation.orderedMessages

      withAnimation {
        showResponse = true
      }
    }

    let response: CompleteResponseSummary
    do {
      let config = try fetchBackendConfig(context: viewContext)
      let messages = [RoleMessage(role: "system", content: systemPrompt)]
        + messages.compactMap({ $0.text }).map({ RoleMessage(role: "user", content: $0) })
      let params = CompleteParams(messages: messages,
                                  model: config?.model ?? Model.defaultModelUrl.deletingPathExtension().lastPathComponent,
                                  numCTX: contextLength,
                                  temperature: Float(temperature))
      response = try await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, params: params)
    } catch let error as LlamaServerError {
      handleResponseError(error)
      return
    } catch {
      print("agent listen threw unexpected error", error as Any)
      return
    }

    await MainActor.run {
      m.text = response.text
      m.predictedPerSecond = response.predictedPerSecond ?? -1
      m.responseStartSeconds = response.responseStartSeconds
      m.nPredicted = Int64(response.nPredicted ?? -1)
      m.modelName = response.modelName
      m.updatedAt = Date()

      playReceiveSound()
      do {
        try viewContext.save()
      } catch {
        print("error creating message", error.localizedDescription)
      }

      if pendingMessage?.text != nil,
         !pendingMessage!.text!.isEmpty,
         response.text.hasPrefix(agent.pendingMessage),
         m == pendingMessage {
        pendingMessage = nil
        agent.pendingMessage = ""
      }

      if conversation == agentConversation {
        messages = agentConversation.orderedMessages
      }
    }
  }

  private func fetchBackendConfig(context: NSManagedObjectContext) throws -> BackendConfig? {
    let backendType: BackendType = BackendType(rawValue: backendTypeID ?? "") ?? .local
    let req = BackendConfig.fetchRequest()
    req.predicate = NSPredicate(format: "backendType == %@", backendType.rawValue)
    return try context.fetch(req).first
  }
}

#Preview {
  let ctx = PersistenceController.preview.container.viewContext
  let c = try! Conversation.create(ctx: ctx)
  let cm = ConversationManager()
  cm.currentConversation = c
  cm.agent = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

  let question = Message(context: ctx)
  question.conversation = c
  question.text = "how can i check file size in swift?"

  let response = Message(context: ctx)
  response.conversation = c
  response.fromId = "llama"
  response.text = """
      Hi! You can use `FileManager` to get information about files, including their sizes. Here's an example of getting the size of a text file:
      ```swift
      let path = "path/to/file"
      do {
          let attributes = try FileManager.default.attributesOfItem(atPath: path)
          if let fileSize = attributes[FileAttributeKey.size] as? UInt64 {
              print("The file is \\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))")
          }
      } catch {
          // Handle any errors
      }
      ```
      """


  return ConversationView()
    .environment(\.managedObjectContext, ctx)
    .environmentObject(cm)
}

#Preview("null state") {
  let ctx = PersistenceController.preview.container.viewContext
  let c = try! Conversation.create(ctx: ctx)
  let cm = ConversationManager()
  cm.currentConversation = c
  cm.agent = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

  return ConversationView()
    .environment(\.managedObjectContext, ctx)
    .environmentObject(cm)
}

