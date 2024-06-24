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

  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("systemPrompt") private var systemPrompt: String = DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength: Int = DEFAULT_CONTEXT_LENGTH
  @AppStorage("playSoundEffects") private var playSoundEffects = true
  @AppStorage("temperature") private var temperature: Double?
  @AppStorage("useGPU") private var useGPU: Bool = DEFAULT_USE_GPU
  @AppStorage("serverHost") private var serverHost: String?
  @AppStorage("serverPort") private var serverPort: String?
  @AppStorage("serverTLS") private var serverTLS: Bool?
  @AppStorage("fontSizeOption") private var fontSizeOption: Int = 12

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>

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

  var selectedModel: Model? {
    if selectedModelId != AISettingsView.remoteModelOption,
      let selectedModelId = self.selectedModelId {
      models.first(where: { $0.id?.uuidString == selectedModelId })
    } else {
      models.first
    }
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
    }
      .textSelection(.enabled)
      .font(.system(size:CGFloat( fontSizeOption)))
      .safeAreaInset(edge: .bottom, spacing: 0) {
      MessageTextField { s in
        submit(s)
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
    guard
      let selectedModelId = modelId ?? self.selectedModelId,
      !selectedModelId.isEmpty
    else { return }

    messages = c.orderedMessages
        

    // warmup the agent if it's cold or model has changed
    Task {
      if selectedModelId == AISettingsView.remoteModelOption {
        await initializeServerRemote()
      } else {
        await initializeServerLocal(modelId: selectedModelId)
      }
    }
  }

  private func initializeServerLocal(modelId: String) async {
    guard let id = UUID(uuidString: modelId)
    else { return }
    
    let llamaPath = await agent.llama.modelPath
    let req = Model.fetchRequest()
    req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    if let model = try? viewContext.fetch(req).first,
       let modelPath = model.url?.path(percentEncoded: false),
       modelPath != llamaPath {
      await agent.llama.stopServer()
      agent.llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
    }
  }

  private func initializeServerRemote() async {
    guard let tls = serverTLS,
          let host = serverHost,
          let port = serverPort
    else { return }
    await agent.llama.stopServer()
    agent.llama = LlamaServer(contextLength: contextLength, tls: tls, host: host, port: port)
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

  func submit(_ input: String) {
    if (agent.status == .processing || agent.status == .coldProcessing) {
      Task {
        await agent.interrupt()

        Task.detached(priority: .userInitiated) {
          try? await Task.sleep(for: .seconds(1))
          await submit(input)
        }
      }
      return
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

    Task {
      var response: LlamaServer.CompleteResponse
      do {
        response = try await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, messages: messages, temperature: temperature)
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

        if conversation != agentConversation {
          return
        }

        messages = agentConversation.orderedMessages
      }
    }
  }
}

#Preview {
  let ctx = PersistenceController.preview.container.viewContext
  let c = try! Conversation.create(ctx: ctx)
  let cm = ConversationManager()
  cm.currentConversation = c
  cm.agent = Agent(id: "llama", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

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
  cm.agent = Agent(id: "llama", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

  return ConversationView()
    .environment(\.managedObjectContext, ctx)
    .environmentObject(cm)
}

