//
//  ConversationManager.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/11/23.
//

import Foundation
import CoreData
import SwiftUI

class ConversationManager: ObservableObject {
  var summonRegistered = false
  
  @AppStorage("systemPrompt") private var systemPrompt: String = Agent.DEFAULT_SYSTEM_PROMPT
  @AppStorage("selectedModelId") private var selectedModelId: String = Model.defaultModelId

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
  
  func newConversation(viewContext: NSManagedObjectContext, openWindow: OpenWindowAction) {
    // bring conversation window to front
    let conversationWindow = NSApp.windows.first(where: { $0.title != "Settings" })
    if conversationWindow != nil {
      conversationWindow?.makeKeyAndOrderFront(self)
    } else {
      // conversation window is not open, so open it
      openWindow(id: "main")
    }
    
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
  
  func rebootAgent(systemPrompt: String? = nil, model: Model? = nil, viewContext: NSManagedObjectContext) {
    let prompt = systemPrompt ?? self.systemPrompt
    let url = model?.url != nil ? model!.url! : LlamaServer.DEFAULT_MODEL_URL
    
    Task {
      await agent.llama.stopServer()
      await MainActor.run {
        agent = Agent(id: "Llama", prompt: agent.prompt, systemPrompt: prompt, modelPath: url.path)
        loadingModelId = model?.id?.uuidString ?? Model.defaultModelId
      }
      print("agent.warmup()")
      print("prompt", prompt)
      do {
        model?.error = nil
        print("agent.warmup calling llama.complete")
        try await agent.warmup()
      } catch LlamaServerError.modelError {
        print("caught modelError on warmup")
        await MainActor.run {
          selectedModelId = Model.defaultModelId
        }
        model?.error = "Error loading model"
      } catch (let error) {
        print("agent warmup threw unexpected error", error.localizedDescription)
      }

      await MainActor.run {
        loadingModelId = nil
        try? viewContext.save()
      }
    }
  }
}
