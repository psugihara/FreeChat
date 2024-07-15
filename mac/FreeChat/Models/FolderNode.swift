//
//  FolderNode.swift
//  FreeChat
//
//  Created by Sebastian Gray on 10/7/2024.
//

import Foundation
import CoreData

public struct FolderNode: Identifiable, Hashable {
  public let id = UUID()
  public let folder: Folder
  public var subfolders: [FolderNode]
  public var conversations: [Conversation]
  public var isOpen: Bool
  
  public static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
      return lhs.id == rhs.id
  }
  
  public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
  }
}

public enum NavItem: Identifiable, Hashable {
    case folder(FolderNode)
    case conversation(Conversation)
    
    public var id: String {
        switch self {
        case .folder(let node):
            return "folder_\(node.id)"
        case .conversation(let conversation):
            return "conversation_\(conversation.objectID)"
        }
    }
}
