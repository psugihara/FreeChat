//
//  Message+Extensions.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import CoreData
import Foundation

extension Message {
  static let USER_SPEAKER_ID = "### User"

  static func create(
    text: String,
    fromId: String,
    conversation: Conversation,
    systemPrompt: String,
    inContext ctx: NSManagedObjectContext
  ) throws -> Self {
    let record = self.init(context: ctx)
    record.text = text
    record.conversation = conversation
    record.createdAt = Date()
    record.systemPrompt = systemPrompt
    conversation.lastMessageAt = record.createdAt
    record.fromId = fromId

    try ctx.save()

    return record
  }

  public override func willSave() {
    super.willSave()

    if !isDeleted, changedValues()["updatedAt"] == nil {
      self.setValue(Date(), forKey: "updatedAt")
    }

    if !isDeleted, createdAt == nil {
      self.setValue(Date(), forKey: "createdAt")
    }
  }
}
