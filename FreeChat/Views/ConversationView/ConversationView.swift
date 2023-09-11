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
    conversationManager.currentConversation!
  }
  
  @ObservedObject var agent: Agent
  @State var pendingMessage: Message?
  
  @State var messages: [Message] = []
  
  @State var showUserMessage = true
  @State var showResponse = true
  @State private var scrollPositions = [String: CGFloat]()
  @State var pendingMessageText = ""
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
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
                  .onAppear {
                    scrollToLastIfRecent(proxy)
                  }
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
          agent.$pendingMessage.debounce(for: .seconds(1), scheduler: RunLoop.main)
        ) { _ in
          scrollToLastIfRecent(proxy)
        }
      }
      .textSelection(.enabled)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        MessageTextField(conversation: conversation, onSubmit: { s in
          submit(s)
        })
      }
      .frame(maxWidth: .infinity)
      .onAppear {
        messages = conversation.orderedMessages
        Task {
          if agent.status == .cold, agent.prompt != conversation.prompt {
            agent.prompt = conversation.prompt ?? ""
            await agent.warmup()
          }
        }
      }
      .onChange(of: conversation) { nextConvo in
        messages = nextConvo.orderedMessages
        if agent.status == .cold, agent.prompt != conversation.prompt {
          agent.prompt = nextConvo.prompt ?? ""
          Task {
            await agent.warmup()
          }
        }
      }
      .onReceive(
        agent.$pendingMessage.throttle(for: .seconds(0.07), scheduler: RunLoop.main, latest: true)
      ) { text in
        if conversation.prompt != nil, agent.prompt.hasPrefix(conversation.prompt!) {
          pendingMessageText = text
        }
      }
      
    }
    .navigationTitle(conversation.titleWithDefault)
  }
  
  private func scrollToLastIfRecent(_ proxy: ScrollViewProxy) {
    let fiveSecondsAgo = Date() - TimeInterval(5) // 5 seconds ago
    let last = messages.last
    if last?.updatedAt != nil, last!.updatedAt! >= fiveSecondsAgo {
      proxy.scrollTo(last!.id, anchor: .bottom)
    }
  }
  
  @MainActor
  func submit(_ input: String) {
    if (agent.status == .processing || agent.status == .coldProcessing) {
      Task {
        await agent.interrupt()
        submit(input)
      }
      return
    }
    
    showUserMessage = false
    // Create user's message
    _ = try! Message.create(text: input, fromId: Message.USER_SPEAKER_ID, conversation: conversation, inContext: viewContext)
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
    agent.prompt = conversation.prompt ?? agent.prompt
    
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
      let response = await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, message: input)

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
        
        pendingMessage = nil
        agent.pendingMessage = ""
        
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
    let a = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "")
    let cm = ConversationManager()
    cm.currentConversation = c
    
    return ConversationView(agent: a)
      .environment(\.managedObjectContext, ctx)
      .environmentObject(cm)
  }
}

