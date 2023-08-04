//
//  ConversationView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import MarkdownUI

struct FTextFieldStyle: TextFieldStyle {
  @FocusState private var isFocused: Bool
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .textFieldStyle(.plain)
      .frame(maxWidth: .infinity)
      .padding(6)
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0.5)
      .focusable()
      .focused($isFocused)
      .overlay(
        RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.5), lineWidth: 2).opacity(isFocused ? 1 : 0).scaleEffect(isFocused ? 1 : 1.04)
      )
      .animation(isFocused ? .easeIn(duration: 0.2) : .easeOut(duration: 0.0), value: isFocused)
  }
}

struct ConversationView: View {
  enum Position {
    case bottom
  }
  
  @Environment(\.managedObjectContext) private var viewContext
  
  var conversation: Conversation
  @State var input = ""
  
  @ObservedObject var agent: Agent
  @FocusState var messageFieldFocused: Bool?
  
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
          MessageView(m).id(m == messages.last && agent.status != .processing ? Position.bottom : nil)
          if m == messages.last {
            if agent.pendingMessage != "" {
              Text(agent.pendingMessage)
                .id(Position.bottom)
            } else if agent.status == .processing {
              Text("thinking...")
                .id(Position.bottom)
                .onAppear {
                  proxy.scrollTo(Position.bottom, anchor: .bottom)
                }
            }
          }
        }
        .textSelection(.enabled)
        .listRowSeparator(.visible)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          TextField("Message", text: $input, axis: .vertical)
            .onSubmit { submit() }
            .submitLabel(.send)
            .focused($messageFieldFocused, equals: true)
            .textFieldStyle(FTextFieldStyle())
            .padding(.all, 8)
            .background(.thinMaterial)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: messages.count) { _ in
          proxy.scrollTo(Position.bottom, anchor: .bottom)
        }
        .onChange(of: agent.pendingMessage) { _ in
          proxy.scrollTo(Position.bottom, anchor: .bottom)
        }
        .onChange(of: conversation) { _ in
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.messageFieldFocused = true
          }
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
  
  func submit() {
    if (agent.status == .processing) {
      input += "\n"
      return
    }
    let submitted = input
    input = ""
    _ = try! Message.create(text: submitted, fromId: Message.USER_SPEAKER_ID, conversation: conversation, inContext: viewContext)
    Task {
      let text = await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, message: submitted)
      _ = try Message.create(text: text, fromId: agent.id, conversation: conversation, inContext: viewContext)
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

