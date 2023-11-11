//
//  FeedbackButton.swift
//  FreeChat
//
//  Created by Peter Sugihara on 11/11/23.
//

import SwiftUI

struct FeedbackButton: View {
  enum Status {
    case ready
    case loading
    case failure
    case success
  }

  let message: Message

  @State var confirm = false
  @State var showPostSheet = false
  @State var status: Status = .ready

  var body: some View {
    Button(action: {
      confirm = true
    }, label: {
      Image(systemName: "hand.thumbsup.circle")
    })
      .buttonStyle(.plain)
      .confirmationDialog("Share Feedback", isPresented: $confirm, actions: {
      Button("Cancel", role: .cancel) {
        confirm = false
      }
      Button(action: postFeedback, label: {
        Text("Share Anonymously")
      })
    }, message: {
      Text("Help train future models by publishing this conversation to an open dataset. Please do not share conversations with sensitive info like your real name.")
    })
      .sheet(isPresented: $showPostSheet, content: {
      switch status {
      case .loading, .ready:
        ProgressView()
      case .failure:
        Text("Error posting, try again later")
      case .success:
        Text("Success!")
      }
    })
  }

  private func postFeedback() {
    showPostSheet = true
    status = .loading
    print("post feedback")

    let messages = message.conversation?.orderedMessages
      .filter { $0.createdAt == nil || message.createdAt == nil || $0.createdAt! <= message.createdAt! }
      .map { HumanFeedbackMessage(fromUser: $0.fromId == Message.USER_SPEAKER_ID, text: $0.text ?? "") }
    let feedback = HumanFeedback(
      messages: messages ?? [],
      modelName: message.modelName ?? "",
      promptTemplate: message.promptTemplate ?? ""
    )

    Task {
      let url = URL(string: "http://localhost:3000/api/conversation")!
      var request = URLRequest(url: url)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpMethod = "POST"
      let encoder = JSONEncoder()
      do {
        let data = try encoder.encode(feedback)
        request.httpBody = data
        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)

        print("responseData", responseData)
        print("response", response)

        status = .success
      } catch {
        status = .failure
      }

    }

  }
}

struct HumanFeedback: Codable {
  var messages: [HumanFeedbackMessage]
  var modelName: String
  var promptTemplate: String
  var lastSystemPrompt: String?
}

struct HumanFeedbackMessage: Codable {
  let fromUser: Bool
  let text: String
}

//#Preview {
//    FeedbackButton()
//}
