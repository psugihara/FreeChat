//
//  MessageView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/4/23.
//

import SwiftUI
import MarkdownUI

struct MessageView: View {
  let m: Message
  let overrideText: String // for streaming replies
  
  init(_ m: Message, overrideText: String = "") {
    self.m = m
    self.overrideText = overrideText
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack(alignment: .firstTextBaseline) {
        Text(m.fromId == Message.USER_SPEAKER_ID ? "You" : (m.fromId ?? "bot"))
          .fontWeight(.bold)
        if overrideText != "" {
          ProgressView().controlSize(.mini).padding(.leading, 2)
        } else {
          Text(m.createdAt ?? Date(), formatter: messageTimestampFormatter)
            .font(.caption)
            .foregroundColor(.gray)
        }
      }.padding(.bottom, 1)
      
      Markdown(overrideText == "" && m.text != nil ? m.text! : overrideText)
        .markdownTheme(.docC)
    }
    .padding(.vertical, 3)
    .padding(.horizontal, 3)
  }
}

private let messageTimestampFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
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
      MessageView($0)
    }.environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
