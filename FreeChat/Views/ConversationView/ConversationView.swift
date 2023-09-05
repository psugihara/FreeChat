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
  
  @ObservedObject var conversation: Conversation
  
  @ObservedObject var agent: Agent
  @State var pendingMessage: Message?
  
  @State var messages: [Message] = []
  
  @State var input = ""
  @State var pendingMessageOpacity = 0.0
  @State private var scrollPositions = [String: CGFloat]()
  @State var quickPrompts = QuickPromptButton.quickPrompts.shuffled().prefix(4)
  
  var nullState: some View {
    Grid {
      GridRow {
        ForEach(quickPrompts) { prompt in
          QuickPromptButton(input: $input, prompt: prompt)
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity)
  }
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading) {
          ForEach(messages) { m in
            if m == messages.last! {
              if m == pendingMessage {
                Group {
                  MessageView(pendingMessage!, overrideText: agent.pendingMessage, agentStatus: agent.status)
                    .onAppear {
                      scrollToLastIfRecent(proxy)
                    }
                }.offset(x: -30 * (1 - pendingMessageOpacity))
                  .opacity(pendingMessageOpacity)
                  .animation(Animation.easeOut(duration: 0.6), value: pendingMessageOpacity)
                  .id("\(m.id)\(m.updatedAt as Date?)")
                
              } else {
                MessageView(m, agentStatus: nil)
                  .id("\(m.id)\(m.updatedAt as Date?)")
                  .transition(.opacity)
                  .onAppear {
                    scrollToLastIfRecent(proxy)
                  }
              }
            } else {
              MessageView(m, agentStatus: nil).transition(.opacity).id("\(m.id)\(m.updatedAt as Date?)")
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
        VStack(spacing: 0) {
          if messages.count == 0 {
            nullState
          }
          MessageTextField(input: $input, conversation: conversation, onSubmit: { s in
            submit(input)
          })
        }
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
        quickPrompts = QuickPromptButton.quickPrompts.shuffled()[0...4]
        messages = nextConvo.orderedMessages
        if agent.status == .cold, agent.prompt != conversation.prompt {
          agent.prompt = nextConvo.prompt ?? ""
          Task {
            await agent.warmup()
          }
        }
      }
    }
  }
  
  func scrollToLastIfRecent(_ proxy: ScrollViewProxy) {
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
    
    // Create user's message
    _ = try! Message.create(text: input, fromId: Message.USER_SPEAKER_ID, conversation: conversation, inContext: viewContext)
    messages = conversation.orderedMessages
    pendingMessageOpacity = 0
    
    // Pending message for bot's reply
    let m = Message(context: viewContext)
    m.fromId = agent.id
    m.createdAt = Date()
    m.updatedAt = m.createdAt
    m.text = ""
    pendingMessage = m
    agent.prompt = conversation.prompt ?? agent.prompt
    let currentConvo = conversation
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      m.conversation = conversation
      messages = conversation.orderedMessages
      
      withAnimation {
        pendingMessageOpacity = 1
      }
    }
    
    Task {
      let response = await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, message: input)
      
      await MainActor.run {
        currentConvo.prompt = agent.prompt
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
        withAnimation {
          messages = conversation.orderedMessages
          pendingMessage = nil
          agent.pendingMessage = ""
        }
      }
    }
  }
  
}

//struct ConversationView_Previews_Container: View {
//  var body: some View {
//
//  }
//}

struct ConversationView_Previews: PreviewProvider {
  static var previews: some View {
    let ctx = PersistenceController.preview.container.viewContext
    let c = try! Conversation.create(ctx: ctx)
    let a = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "")
    //    let _ = try! Message.create(text: "hello", conversation: c, inContext: ctx)
    //    let _ = try! Message.create(text: "Hi", conversation: c, inContext: ctx)
    
    //    ConversationView_Previews_Container
    ConversationView(conversation: c, agent: a).environment(\.managedObjectContext, ctx)
  }
}

