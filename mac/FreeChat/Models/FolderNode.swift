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

enum NavItem: Identifiable {
    case folder(FolderNode)
    case conversation(Conversation)

    
  
  
    var id: AnyHashable {
        switch self {
        case .folder(let folderNode):
            return AnyHashable(folderNode.folder.objectID)
        case .conversation(let conversation):
            return AnyHashable(conversation.id)
        }
    }
}
