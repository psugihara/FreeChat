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
                .scaleEffect(x: showResponse ? 1 : 0.5, y: showResponse ? 1 : 0.5, anchor: .bottomLeading)
                .opacity(showResponse ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 170, damping: 20), value: showResponse)
                .id("\(m.id)\(m.updatedAt as Date?)")
            } else {
              MessageView(m, agentStatus: nil)
                .id("\(m.id)\(m.updatedAt as Date?)")
                .scaleEffect(x: showUserMessage ? 1 : 0.5, y: showUserMessage ? 1 : 0.5, anchor: .bottomLeading)
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
        if conversation.prompt != nil,
           text != pendingMessageText,
            agent.prompt.hasPrefix(conversation.prompt!) {
          pendingMessageText = text
        }
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
    .navigationTitle(conversation.titleWithDefault)
    .alert(isPresented: $showErrorAlert, error: llamaError) { _ in
      Button("OK") {
        llamaError = nil
      }
    } message: { error in
      Text(error.recoverySuggestion ?? "Try again later.")
    }
  }
  
  private func showConversation(_ c: Conversation) {
    messages = c.orderedMessages
    if agent.status == .cold || agent.prompt != c.prompt {
      agent.prompt = c.prompt ?? ""
      Task {
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
    
    // Pending message for bot's reply
    let m = Message(context: viewContext)
    m.fromId = agent.id
    m.createdAt = Date()
    m.updatedAt = m.createdAt
    m.text = ""
    pendingMessage = m
    
    // Replace the agent's prompt if they don't know the conversation.
    if conversation.prompt != nil && !agent.prompt.hasPrefix(conversation.prompt!) {
      agent.prompt = conversation.prompt!
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      if agentConversation != conversation {
        return
      }
      
      m.conversation = conversation
      messages = agentConversation.orderedMessages
      
      withAnimation {
        showResponse = true
      }
    }
    
    Task {
      var response: LlamaServer.CompleteResponse
      do {
        response = try await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, message: input)
      } catch let error as LlamaServerError {
        handleResponseError(error)
        return
      } catch {
        print("agent listen threw unexpected error", error.localizedDescription)
        return
      }
        
      await MainActor.run {
        agentConversation.prompt = agent.prompt
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

struct ConversationView_Previews: PreviewProvider {
  static var previews: some View {
    let ctx = PersistenceController.preview.container.viewContext
    let c = try! Conversation.create(ctx: ctx)
    let cm = ConversationManager()
    cm.currentConversation = c
    cm.agent = Agent(id: "llama", prompt: "", systemPrompt: "")
    
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
}

