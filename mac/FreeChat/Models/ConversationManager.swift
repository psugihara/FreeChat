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

  @AppStorage("backendTypeID") private var backendTypeID: String?
  @AppStorage("systemPrompt") private var systemPrompt: String = DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength: Int = DEFAULT_CONTEXT_LENGTH

  @Published var agent: Agent = Agent(id: "Llama", prompt: "", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)
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
    guard let url = model.url else { return }
    let systemPrompt = systemPrompt ?? self.systemPrompt

    Task {
      await agent.llama.stopServer()

      let messages = currentConversation.orderedMessages.map { $0.text ?? "" }
      let convoPrompt = model.template.run(systemPrompt: systemPrompt, messages: messages)
      agent = Agent(id: "Llama", prompt: convoPrompt, systemPrompt: systemPrompt, modelPath: url.path, contextLength: contextLength)

      do {
        let backendType: BackendType = BackendType(rawValue: backendTypeID ?? "") ?? .local
        let context = PersistenceController.shared.container.newBackgroundContext()
        let config = try fetchBackendConfig(context: context) ?? BackendConfig(context: context)
        agent.createBackend(backendType, contextLength: contextLength, config: config)
      } catch { print("error fetching backend config", error) }
      loadingModelId = model.id?.uuidString

      model.error = nil
      loadingModelId = nil
      try? viewContext.save()
    }
  }

  private func fetchBackendConfig(context: NSManagedObjectContext) throws -> BackendConfig? {
    let backendType: BackendType = BackendType(rawValue: backendTypeID ?? "") ?? .local
    let req = BackendConfig.fetchRequest()
    req.predicate = NSPredicate(format: "backendType == %@", backendType.rawValue)
    return try context.fetch(req).first
  }
}
