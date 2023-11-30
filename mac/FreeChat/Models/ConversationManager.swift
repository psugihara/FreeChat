//
//  ConversationManager.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/11/23.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class ConversationManager: ObservableObject {
  static let shared = ConversationManager()

  var summonRegistered = false

  @AppStorage("systemPrompt") private var systemPrompt: String = Agent.DEFAULT_SYSTEM_PROMPT
  @AppStorage("selectedModelId") private var selectedModelId: String = Model.unsetModelId

  @Published var agent: Agent = Agent(id: "Llama", prompt: "", systemPrompt: "", modelPath: "")
  @Published var loadingModelId: String?

  private static var dummyConversation: Conversation = {
    let tempMoc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return Conversation(context: tempMoc)
  }()

  // in the foreground
  @Published var currentConversation: Conversation = ConversationManager.dummyConversation

  func showConversation() -> Bool {
    return currentConversation != ConversationManager.dummyConversation
  }

  func unsetConversation() {
    currentConversation = ConversationManager.dummyConversation
  }

  func bringConversationToFront(openWindow: OpenWindowAction) {
    // bring conversation window to front
    if let conversationWindow = NSApp.windows.first(where: { $0.title == currentConversation.titleWithDefault || $0.title == "FreeChat" }) {
      conversationWindow.makeKeyAndOrderFront(self)
    } else {
      // conversation window is not open, so open it
      openWindow(id: "main")
    }
  }

  func newConversation(viewContext: NSManagedObjectContext, openWindow: OpenWindowAction) {
    bringConversationToFront(openWindow: openWindow)

    do {
      // delete old conversations with no messages
      let fetchRequest = Conversation.fetchRequest()
      let conversations = try viewContext.fetch(fetchRequest)
      for conversation in conversations {
        if conversation.messages?.count == 0 {
          viewContext.delete(conversation)
        }
      }

      // make a new convo
      try withAnimation {
        let c = try Conversation.create(ctx: viewContext)
        currentConversation = c
      }
    } catch (let error) {
      print("error creating new conversation", error.localizedDescription)
    }
  }

  @MainActor
  func rebootAgent(systemPrompt: String? = nil, model: Model, viewContext: NSManagedObjectContext) {
    let systemPrompt = systemPrompt ?? self.systemPrompt
    guard let url = model.url else {
      return
    }

    Task {
      await agent.llama.stopServer()

      let messages = currentConversation.orderedMessages.map { $0.text ?? "" }
      let convoPrompt = model.template.run(systemPrompt: systemPrompt, messages: messages)
      agent = Agent(id: "Llama", prompt: convoPrompt, systemPrompt: systemPrompt, modelPath: url.path)
      loadingModelId = model.id?.uuidString ?? Model.unsetModelId

//      do {
        model.error = nil
//        try await agent.warmup()
//      } catch LlamaServerError.modelError {
//        selectedModelId = Model.unsetModelId
//        model.error = "Error loading model"
//      } catch (let error) {
//        print("agent warmup threw unexpected error", error.localizedDescription)
//      }

      loadingModelId = nil
      try? viewContext.save()
    }
  }
}
