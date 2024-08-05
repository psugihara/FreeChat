//
//  Folder+Extensions.swift
//  FreeChat
//
//  Created by Sebastian Gray on 5/7/2024.
//

import Foundation
import CoreData


extension Folder {
    
  static func create(ctx: NSManagedObjectContext, name: String, parent: Folder? = nil) throws -> Self {
          let folder = self.init(context: ctx)
          folder.name = name
          if let parent = parent {
              parent.addSubfolder(folder) // Assuming you have a 'children' relationship
          }
          try ctx.save()
          return folder
      }
  
  func addConversation(_ conversation: Conversation) {
          conversation.moveToFolder(self)
      }
    
  var subfolders: [Folder] {
      let childFolders = self.child as? Set<Folder> ?? []
        
      return Array(childFolders).sorted { $0.name ?? "" < $1.name ?? "" }
  }
  
  func addSubfolder(_ subfolder: Folder) {
      addToChild(subfolder)
  }
  
  func setSysPrompt(_ prompt: String?) {
      self.sysPrompt = prompt
  }
  
  func rename(to newName: String) {
          if !newName.isEmpty && newName != self.name {
              self.name = newName
              try? self.managedObjectContext?.save()
          }
      }
  
  public override func willSave() {
      super.willSave()
      
      //if !isDeleted, changedValues()["updatedAt"] == nil {
      //    self.setValue(Date(), forKey: "updatedAt")
      //}
  }
}

