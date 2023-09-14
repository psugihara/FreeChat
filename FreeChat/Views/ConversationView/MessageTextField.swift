//
//  MessageTextField.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//

import SwiftUI

struct ChatStyle: TextFieldStyle {
  @Environment(\.colorScheme) var colorScheme
  var focused: Bool
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .textFieldStyle(.plain)
      .frame(maxWidth: .infinity)
      .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
      .padding(8)
      .cornerRadius(12)
        .overlay( // regular border
        Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1)
      )
      .overlay( // focus ring
        Capsule()
          .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
          .scaleEffect(focused ? 1 : 1.02)
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0.5)
          .opacity(focused ? 1 : 0)
      )
      .animation(focused ? .easeIn(duration: 0.2) : .easeOut(duration: 0.0), value: focused)
  }
}

struct MessageTextField: View {
  @State var input: String = ""
  
  @EnvironmentObject var conversationManager: ConversationManager
  var conversation: Conversation {  conversationManager.currentConversation }

  var onSubmit: (String) -> Void
  @State var showNullState = false
  
  @FocusState private var focused: Bool
  
  var nullState: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(QuickPromptButton.quickPrompts) { p in
          QuickPromptButton(input: $input, prompt: p)
          
        }
      }.padding(.horizontal, 10).padding(.top, 200)
      
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
        .textFieldStyle(ChatStyle(focused: focused))
        .submitLabel(.send)
        .padding(.all, 10)
        .onAppear {
          maybeFocus(conversation)
        }
        .onChange(of: conversation) { nextConversation in
          maybeFocus(nextConversation)
        }
        .background(.thinMaterial)
    }
  }
  
  
  var body: some View {
    VStack(alignment: .trailing) {
      if showNullState {
        nullState.transition(.asymmetric(insertion: .push(from: .trailing), removal: .opacity))
      }
      inputField
    }
    .onAppear {
      maybeShowNullState()
    }
    .onChange(of: conversation) { c in
      maybeShowNullState(newMessages: c.messages)
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
