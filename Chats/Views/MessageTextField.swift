//
//  MessageTextField.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//

import SwiftUI

struct ChatStyle: TextFieldStyle {
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

let chatStyle = ChatStyle()

struct MessageTextField: View {
  var conversation: Conversation
  var onSubmit: (String) -> Void

  @State private var input = ""
  @FocusState private var focused: Bool

  var body: some View {
    TextField("Message", text: $input, axis: .vertical)
      .onSubmit {
        onSubmit(input)
        input = ""
      }
      .focused($focused)
      .textFieldStyle(chatStyle)
      .submitLabel(.send)
      .padding(.all, 8)
      .onAppear {
        self.focused = true
      }
      .onChange(of: conversation) { nextConversation in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          if nextConversation.createdAt == nil { return }
          let fiveSecondsAgo = Date() - TimeInterval(5) // 5 seconds ago
          if nextConversation.createdAt! >= fiveSecondsAgo, nextConversation.messages?.count == 0 {
            self.focused = true
          }
        }
      }
  }
}



//#if DEBUG
//struct MessageTextField_Previews: PreviewProvider {
//  static var previews: some View {
//    MessageTextField(conversation: c, onSubmit: { _ in print("submit") })
//      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//  }
//}
//#endif
