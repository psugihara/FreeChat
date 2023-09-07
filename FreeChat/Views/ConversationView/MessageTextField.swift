//
//  MessageTextField.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//

import SwiftUI

struct ChatStyle: TextFieldStyle {
  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) var colorScheme
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .textFieldStyle(.plain)
      .frame(maxWidth: .infinity)
      .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
      .padding(8)
      .cornerRadius(12)
      .focusable()
      .focused($isFocused)
      .overlay(
        Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1)
      )
  }
}

let chatStyle = ChatStyle()

struct MessageTextField: View {
  @State var input: String = ""
  var conversation: Conversation
  var onSubmit: (String) -> Void
  @State var showNullState = false
  
  @FocusState private var focused: Bool
  
  var nullState: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(QuickPromptButton.quickPrompts) { p in
          QuickPromptButton(input: $input, prompt: p)
          
        }
      }.padding(.horizontal, 10).padding(.top, 400)
      
    }.frame(maxWidth: .infinity)
  }
  
  var inputField: some View {
    Group {
      TextField("Message (⌥ + ⏎ for new line)", text: $input, axis: .vertical)
        .onSubmit {
          if CGKeyCode.kVK_Shift.isPressed {
            input += "\n"
          } else {
            onSubmit(input)
            input = ""
          }
        }
        .focused($focused)
        .textFieldStyle(chatStyle)
        .submitLabel(.send)
        .padding(.all, 10)
        .onAppear {
          maybeFocus(conversation)
        }
        .onChange(of: conversation) { nextConversation in
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            maybeFocus(nextConversation)
          }
        }
        .onChange(of: input) { _ in
          focused = true
          
        }
        .background(.thinMaterial)
    }
  }
  
  
  var body: some View {
    VStack(alignment: .trailing) {
      if showNullState {
        nullState.transition(.push(from: .leading))
      }
      inputField
    }
    .onAppear {
      maybeShowNullState()
    }
    .onChange(of: conversation.messages) { m in
      maybeShowNullState(newMessages: m)
    }
    .onChange(of: input) { newInput in
      maybeShowNullState(newInput: newInput)
    }
  }
  
  private func maybeShowNullState(newMessages: NSSet? = nil, newInput: String? = nil) {
    let m = newMessages ?? conversation.messages
    let i = newInput ?? input
    withAnimation {
      showNullState = (m == nil || m!.count == 0) && i == ""
    }
  }
  
  private func maybeFocus(_ conversation: Conversation) {
    if conversation.createdAt == nil { return }
    let fiveSecondsAgo = Date() - TimeInterval(5) // 5 seconds ago
    if conversation.createdAt != nil, conversation.createdAt! >= fiveSecondsAgo, conversation.messages?.count == 0 {
      self.focused = true
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
