//
//  ConversationView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import MarkdownUI

struct ConversationView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject private var conversationManager: ConversationManager
  
  @AppStorage("selectedModelId") private var selectedModelId: String = Model.unsetModelId
  @AppStorage("systemPrompt") private var systemPrompt: String = Agent.DEFAULT_SYSTEM_PROMPT

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>

  var conversation: Conversation {
    conversationManager.currentConversation
  }
  
  var agent: Agent {
    conversationManager.agent
  }
  
  var selectedModel: Model? {
    if selectedModelId == Model.unsetModelId {
      models.first
    } else {
      models.first { i in i.id?.uuidString == selectedModelId }
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
        agent.$pendingMessage.throttle(for: .seconds(0.4), scheduler: RunLoop.main, latest: true)
      ) { _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          autoScroll(proxy)
        }
      }
    }
    .textSelection(.enabled)
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
      Text(error.recoverySuggestion ?? "Try again later.")
    }
  }
  
  private func showConversation(_ c: Conversation, modelId: String? = nil) {
    let selectedModelId = modelId ?? self.selectedModelId
    guard !selectedModelId.isEmpty, selectedModelId != Model.unsetModelId else {
      return
    }

    messages = c.orderedMessages

    // warmup the agent if it's cold or model has changed
    let req = Model.fetchRequest()
    req.predicate = NSPredicate(format: "id = %@", selectedModelId)
    Task {
      let llamaPath = await agent.llama.modelPath
      if let models = try? viewContext.fetch(req),
         let model = models.first,
         let modelPath = model.url?.path(percentEncoded: false),
         modelPath != llamaPath {
        agent.llama = LlamaServer(modelPath: modelPath)
        try? await agent.warmup()
      } else if agent.status == .cold {
        try? await agent.warmup()
      }
    }
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
  
  @MainActor
  func submit(_ input: String) {
    dispatchPrecondition(condition: .onQueue(.main))

    if (agent.status == .processing || agent.status == .coldProcessing) {
      Task {
        await agent.interrupt()
        submit(input)
      }
      return
    }
    
    guard let model = selectedModel else {
      return
    }

    showUserMessage = false
    engageAutoScroll()
    
    // Create user's message
    do {
      _ = try Message.create(text: input, fromId: Message.USER_SPEAKER_ID, conversation: conversation, inContext: viewContext)
    } catch (let error) {
      print("Error creating message", error.localizedDescription)
    }
    showResponse = false
    
    let agentConversation = conversation
    messages = agentConversation.orderedMessages
    withAnimation {
      showUserMessage = true
    }
    
    let messageTexts = messages.map { $0.text ?? "" }
    
    // Pending message for bot's reply
    let m = Message(context: viewContext)
    m.fromId = agent.id
    m.createdAt = Date()
    m.updatedAt = m.createdAt
    m.text = ""
    pendingMessage = m
    
    agent.systemPrompt = systemPrompt

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      if agentConversation != conversation {
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
        response = try await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, messages: messageTexts, template: model.template)
      } catch let error as LlamaServerError {
        handleResponseError(error)
        return
      } catch {
        print("agent listen threw unexpected error", error.localizedDescription)
        return
      }
        
      await MainActor.run {
        m.text = response.text
        m.predictedPerSecond = response.predictedPerSecond ?? -1
        m.responseStartSeconds = response.responseStartSeconds
        m.modelName = response.modelName
        m.updatedAt = Date()
        if m.text == "" {
          viewContext.delete(m)
        }
        do {
          try viewContext.save()
        } catch (let error) {
          print("error creating message", error.localizedDescription)
        }
        
        if pendingMessage?.text != nil,
           !pendingMessage!.text!.isEmpty,
           response.text.hasPrefix(agent.pendingMessage)  {
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
  cm.agent = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "")
  
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
  cm.agent = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "")

  return ConversationView()
    .environment(\.managedObjectContext, ctx)
    .environmentObject(cm)
}

