//
//  MessageView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/4/23.
//

import SwiftUI
import MarkdownUI
import Splash


struct MessageView: View {
  @Environment(\.colorScheme) private var colorScheme
  
  let m: Message
  let overrideText: String // for streaming replies
  let agentStatus: Agent.Status?
  
  init(_ m: Message, overrideText: String = "", agentStatus: Agent.Status?) {
    self.m = m
    self.overrideText = overrideText
    self.agentStatus = agentStatus
  }
  
  var body: some View {
    HStack(alignment: .top) {
      ZStack(alignment: .bottomTrailing) {
        Image(m.fromId == Message.USER_SPEAKER_ID ? "UserAvatar" : "LlamaAvatar")
          .shadow(color: .gray, radius: 1, x: 0, y: 1)
        if agentStatus == .coldProcessing || agentStatus == .processing, m.fromId != Message.USER_SPEAKER_ID {
          ZStack {
            Circle()
              .fill(.background)
              .frame(width: 14, height: 14)
            ProgressView().controlSize(.mini)
          }
          .transition(.opacity)
        }
      }
      .padding(2)
      .padding(.top, 2)
      
      VStack(alignment: .leading) {
        Group {
          if agentStatus == .coldProcessing, overrideText == "" {
            Text("warming up...")
          } else {
            Text(m.createdAt ?? Date(), formatter: messageTimestampFormatter)
          }
        }
        .font(.caption)
        .foregroundColor(.gray)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 1)
        
        Markdown(overrideText == "" && m.text != nil ? m.text! : overrideText)
          .markdownTheme(.freeChat)
          .markdownCodeSyntaxHighlighter(.splash(theme: self.theme))
          .textSelection(.enabled)
      }
      .padding(.top, 3)
      .padding(.bottom, 8)
      .padding(.horizontal, 3)
      .contextMenu {
        if m.text != nil, !m.text!.isEmpty {
          CopyButton(text: m.text!, buttonText: "Copy to clipboard")
        }
      }
    }
  }
  
  private var theme: Splash.Theme {
    // NOTE: We are ignoring the Splash theme font
    switch self.colorScheme {
      case ColorScheme.dark:
        return .wwdc17(withFont: .init(size: 16))
      default:
        return .sunset(withFont: .init(size: 16))
    }
  }
}

private let messageTimestampFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short
  return formatter
}()

struct MessageView_Previews: PreviewProvider {
  static var messages: [Message] {
    let ctx = PersistenceController.preview.container.viewContext
    let c = try! Conversation.create(ctx: ctx)
    let m = try! Message.create(text: "hello there, I'm well! How are **you**?", fromId: "User", conversation: c, inContext: ctx)
    let m2 = try! Message.create(text: "Doing pretty well, can you write me some code?", fromId: "Llama", conversation: c, inContext: ctx)
    return [m, m2]
  }
  
  static var previews: some View {
    List(MessageView_Previews.messages) {
      MessageView($0, agentStatus: .cold)
    }.environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
