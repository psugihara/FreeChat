//
//  Conversation+Extensions.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import Foundation
import CoreData

extension Conversation {
  static func create(ctx: NSManagedObjectContext) throws -> Self {
    let record = self.init(context: ctx)
    record.createdAt = Date()
    
    try ctx.save()
    return record
  }
  
  var orderedMessages: [Message] {
    let set = messages as? Set<Message> ?? []
    return set.sorted {
      $0.createdAt! < $1.createdAt!
    }
  }

  var titleWithDefault: String {
    if title != nil {
      return title!
    } else if messages?.count ?? 0 > 0 {
      let firstMessage = orderedMessages.first!
      let prefix = firstMessage.text?.prefix(20)
      return prefix != nil ? String(prefix!) : dateTitle
    } else {
      return dateTitle
    }
  }
  
  var dateTitle: String {
    titleFormatter.string(from: createdAt ?? Date())
  }

  private var titleFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }

  public override func willSave() {
    super.willSave()

    if !isDeleted, changedValues()["updatedAt"] == nil {
      self.setValue(Date(), forKey: "updatedAt")
    }
  }
}
