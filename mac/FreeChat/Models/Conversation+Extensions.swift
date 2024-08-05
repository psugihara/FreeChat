//
//  Conversation+Extensions.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import Foundation
import CoreData

//extension Conversation: Hashable {
extension Conversation {
  public var id: UUID {
         if uniqueId == nil {
             uniqueId = UUID()
         }
         return uniqueId!
     }
  
  
  
  static func create(ctx: NSManagedObjectContext) throws -> Self {
          let record = self.init(context: ctx)
          record.createdAt = Date()
          record.lastMessageAt = record.createdAt
          record.uniqueId = UUID()  // Set the uniqueId here
          try ctx.save()
          return record
      }

  func moveToFolder(_ folder: Folder?) {
          self.folder = folder
          try? self.managedObjectContext?.save()
      }
  
  var orderedMessages: [Message] {
    let set = messages as? Set<Message> ?? []
    return set.sorted {
      ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
    }
  }

  var titleWithDefault: String {
    if title != nil {
      return title!
    } else if messages?.count ?? 0 > 0 {
      let firstMessage = orderedMessages.first!
      let prefix = firstMessage.text?.prefix(200)
      if let firstLine = prefix?.split(separator: "\n").first {
        return String(firstLine)
      } else {
        return dateTitle
      }
    } else {
      return dateTitle
    }
  }

  var dateTitle: String {
    (createdAt ?? Date())!.formatted(Conversation.titleFormat)
  }

  static let titleFormat = Date.FormatStyle()
    .year()
    .day()
    .month()
    .hour()
    .minute()
    .locale(Locale(identifier: "en_US"))

  public override func willSave() {
    super.willSave()

    if !isDeleted, changedValues()["updatedAt"] == nil {
      self.setValue(Date(), forKey: "updatedAt")
    }
  }
  
  /*
  public func hash(into hasher: inout Hasher) {
      hasher.combine(objectID)
  }*/
  
  public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
      return lhs.objectID == rhs.objectID
  }
  

  
}

