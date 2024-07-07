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
    folder.parent = parent
    try ctx.save()
    return folder
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
  
  public override func willSave() {
      super.willSave()
      
      //if !isDeleted, changedValues()["updatedAt"] == nil {
      //    self.setValue(Date(), forKey: "updatedAt")
      //}
  }
}
