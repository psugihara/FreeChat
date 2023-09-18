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
  
  private static var dummyConversation: Conversation = {
    let tempMoc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return Conversation(context: tempMoc)
  }()
  
  // in the foreground
  @Published var currentConversation: Conversation = ConversationManager.dummyConversation
  
  func hasConversation() -> Bool {
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

}
