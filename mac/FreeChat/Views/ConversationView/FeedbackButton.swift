//
//  FeedbackButton.swift
//  FreeChat
//
//  Created by Peter Sugihara on 11/11/23.
//

import SwiftUI

struct FeedbackButton: View {
  let message: Message

  @State var confirm = false
  var body: some View {
    Button(action: {
      confirm = true
    }, label: {
      Image(systemName: "hand.thumbsup.circle")
    })
      .buttonStyle(.plain)
      .confirmationDialog("Share feedback", isPresented: $confirm, actions: {
      Button("Cancel", role: .cancel) {
        confirm = false
      }
      Button(action: postFeedback, label: {
        Text("Share Anonymously")
      })
    }, message: {
      Text("Help train future models by adding this conversation to an open dataset. Please do not share conversations with sensitive info like your real name.")
    })
  }

  private func postFeedback() {
    print("post feedback")
  }
}

//#Preview {
//    FeedbackButton()
//}
