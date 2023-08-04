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
}
