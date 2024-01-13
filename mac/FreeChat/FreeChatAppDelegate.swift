//
//  FreeChatAppDelegate.swift
//  FreeChat
//

import SwiftUI

class FreeChatAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @Environment(\.openWindow) var openWindow
  @AppStorage("selectedModelId") private var selectedModelId: String?

  func application(_ application: NSApplication, open urls: [URL]) {
    let viewContext = PersistenceController.shared.container.viewContext
    do {
      let req = Model.fetchRequest()
      req.predicate = NSPredicate(format: "name IN %@", urls.map({ $0.lastPathComponent }))
      let existingModels = try viewContext.fetch(req).compactMap({ $0.url })

      for url in urls {
        guard !existingModels.contains(url) else { continue }
        let insertedModel = try Model.create(context: viewContext, fileURL: url)
        selectedModelId = insertedModel.id?.uuidString
      }

      ConversationManager.shared.newConversation(viewContext: viewContext, openWindow: openWindow)
    } catch {
      print("error saving model:", error)
    }
  }
}
