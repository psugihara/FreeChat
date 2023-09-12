//
//  ConversationManager.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/11/23.
//

import Foundation
import CoreData

class ConversationManager: ObservableObject {
  static var dummyConversation: Conversation = {
    print("lazy dummyConversation")
    let tempMoc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return Conversation(context: tempMoc)
  }()
  
  @Published var currentConversation: Conversation = ConversationManager.dummyConversation
  
  func hasConversation() -> Bool {
    return currentConversation != ConversationManager.dummyConversation
  }
}
