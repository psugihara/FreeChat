//
//  ConversationView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import MarkdownUI

struct ConversationView: View {
  enum Position {
    case bottom
  }
  
  @Environment(\.managedObjectContext) private var viewContext
  
  var conversation: Conversation
  
  @ObservedObject var agent: Agent
  @FocusState var messageFieldFocused: Bool
  @State var pendingMessage: Message?
  
  var messages: [Message] {
    let set = conversation.messages as? Set<Message> ?? []
    return set.sorted {
      $0.createdAt! < $1.createdAt!
    }
  }
  
  var body: some View {
    ZStack(alignment: .bottom) {
      ScrollViewReader { proxy in
        List(messages) { m in
          if m == messages.last {
            if pendingMessage != nil {
              MessageView(pendingMessage!, overrideText: agent.pendingMessage == "" ? "..." : agent.pendingMessage)
                .id(Position.bottom)
            } else {
              MessageView(m).id(Position.bottom)
            }
          } else {
            MessageView(m)
          }
        }
        .textSelection(.enabled)
        .listRowSeparator(.visible)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          MessageTextField(conversation: conversation, onSubmit: { s in
            submit(s)
          })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: messages.count) { _ in
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            proxy.scrollTo(Position.bottom, anchor: .bottom)
          }
        }
        .onChange(of: agent.pendingMessage) { _ in
          proxy.scrollTo(Position.bottom, anchor: .bottom)
        }
        .task {
          proxy.scrollTo(Position.bottom, anchor: .bottom)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      Task {
        agent.prompt = conversation.prompt ?? ""
        await agent.warmup()
      }
    }
  }
  
  func submit(_ input: String) {
    if (agent.status == .processing) {
      return
    }
    let submitted = input
    _ = try! Message.create(text: submitted, fromId: Message.USER_SPEAKER_ID, conversation: conversation, inContext: viewContext)
    Task {
      let m = Message(context: viewContext)
      m.fromId = agent.id
      m.createdAt = Date()
      m.text = ""
      m.conversation = conversation
      pendingMessage = m
      agent.prompt = conversation.prompt ?? agent.prompt
      let text = await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, message: submitted)
      pendingMessage = nil
      m.text = text
      conversation.prompt = agent.prompt
      try viewContext.save()
      agent.pendingMessage = ""
    }
  }

}

//struct ConversationView_Previews: PreviewProvider {
//  static var previews: some View {
//    let ctx = PersistenceController.preview.container.viewContext
//    let c = try! Conversation.create(ctx: ctx)
//    let _ = try! Message.create(text: "hello", conversation: c, inContext: ctx)
//    let _ = try! Message.create(text: "Hi", conversation: c, inContext: ctx)
//
//
//    ConversationView(conversation: c).environment(\.managedObjectContext, ctx)
//  }
//}

