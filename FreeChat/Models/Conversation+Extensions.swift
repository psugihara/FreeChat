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

  var titleWithDefault: String {
    title ?? titleFormatter.string(from: createdAt ?? Date())
  }

  private var titleFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
  }

  public override func willSave() {
    super.willSave()

    if !isDeleted, changedValues()["updatedAt"] == nil {
      self.setValue(Date(), forKey: "updatedAt")
    }
  }
}
