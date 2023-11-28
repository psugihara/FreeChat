//
//  FeedbackButton.swift
//  FreeChat
//
//  Created by Peter Sugihara on 11/11/23.
//

import SwiftUI

struct FeedbackButton: View {

  enum ThumbDirection {
    case up
    case down
  }

  public static let PENDING_FEEDBACK_ID = "pending"

  @Environment(\.managedObjectContext) private var viewContext

  @StateObject var network = Network.shared

  #if DEBUG
    let host = "http://localhost:3000"
  #else
    let host = "https://www.otherbrain.world"
  #endif

  enum Status {
    case ready
    case loading
    case failure
    case success
  }

  @ObservedObject var message: Message
  let thumbs: ThumbDirection

  @State var confirm = false
  @State var showPostSheet = false
  @State var status: Status = .ready
  @State var showOfflineAlert = false

  var body: some View {
    Button(action: {
      if let feedbackId = message.feedbackId,
        feedbackId != FeedbackButton.PENDING_FEEDBACK_ID,
        status != .failure,
        let url = URL(string: "\(host)/api/label-human-feedback/\(feedbackId)") {
        NSWorkspace.shared.open(url)
      } else if network.isConnected {
        confirm = true
      } else {
        showOfflineAlert = true
      }
    }, label: {
      if message.feedbackId != nil,
        message.feedbackId != FeedbackButton.PENDING_FEEDBACK_ID,
        status != .failure {
        Image(systemName: "checkmark.circle.fill")
          .help("View Feedback")
      } else {
        if thumbs == .up {
          Image(systemName: "hand.thumbsup.circle")
            .help("Share feedback")
        } else {
          Image(systemName: "hand.thumbsdown.circle")
            .help("Share feedback")
        }
      }
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
      .alert("You're Offline", isPresented: $showOfflineAlert, actions: {
      Button("OK") {
        showOfflineAlert = false
      }
    }, message: {
      Text("Check your internet and try again.")
    })
  }

  private func postFeedback() {
    showPostSheet = true
    status = .loading
    message.feedbackId = FeedbackButton.PENDING_FEEDBACK_ID

    let messages = message.conversation?.orderedMessages
      .filter { $0.createdAt == nil || message.createdAt == nil || $0.createdAt! <= message.createdAt! }
      .map { HumanFeedbackMessage(fromUser: $0.fromId == Message.USER_SPEAKER_ID, text: $0.text ?? "") }
    let feedback = HumanFeedback(
      messages: messages ?? [],
      modelName: message.modelName ?? "",
      promptTemplate: message.promptTemplate ?? "",
      lastSystemPrompt: message.systemPrompt ?? "",
      quality: thumbs == .up ? 5 : 1
    )

    Task {
      let url = URL(string: "\(host)/api/human-feedback")
      do {
        var request = URLRequest(url: url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let encoder = JSONEncoder()

        let data = try encoder.encode(feedback)
        request.httpBody = data
        let (responseData, response) = try await URLSession.shared.data(for: request)

        #if DEBUG
          print("response", response)
        #endif
        let statusCode = (response as! HTTPURLResponse).statusCode

        if statusCode == 200,
          let json = try? JSONDecoder().decode(HumanFeedbackResponse.self, from: responseData) {
          message.feedbackId = json.id
          try viewContext.save()
          status = .success

          if let feedbackId = message.feedbackId,
            let url = URL(string: "\(host)/api/label-human-feedback/\(feedbackId)") {
            NSWorkspace.shared.open(url)
          } else {
            status = .failure
          }

        } else {
          print("FAILURE")
          status = .failure
        }

      } catch {
        print("error posting to \(url?.debugDescription ?? "null")", error.localizedDescription)
        status = .failure
      }

      if message.feedbackId == FeedbackButton.PENDING_FEEDBACK_ID {
        message.feedbackId = nil
      }
    }

  }
}

struct HumanFeedback: Codable {
  var messages: [HumanFeedbackMessage]
  var modelName: String
  var promptTemplate: String
  var lastSystemPrompt: String
  var client = "FreeChat \(Bundle.main.infoDictionary!["CFBundleShortVersionString"]!)"
  var quality: Int
}

struct HumanFeedbackMessage: Codable {
  let fromUser: Bool
  let text: String
}

struct HumanFeedbackResponse: Codable {
  let id: String
}

//#Preview {
//    FeedbackButton()
//}
