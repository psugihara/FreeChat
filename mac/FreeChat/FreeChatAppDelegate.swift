//
//  FreeChatAppDelegate.swift
//  FreeChat
//

import SwiftUI

class FreeChatAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("backendTypeID") private var backendTypeID: String = BackendType.local.rawValue
  
  func application(_ application: NSApplication, open urls: [URL]) {
    backendTypeID = BackendType.local.rawValue
    let viewContext = PersistenceController.shared.container.viewContext
    do {
      let req = Model.fetchRequest()
      req.predicate = NSPredicate(format: "name IN %@", urls.map({ $0.lastPathComponent }))
      let existingModels = try viewContext.fetch(req)

      for url in urls {
        guard !existingModels.compactMap({ $0.url }).contains(url) else { continue }
        let insertedModel = try Model.create(context: viewContext, fileURL: url)
        selectedModelId = insertedModel.id?.uuidString
      }

      if urls.count == 1 { selectedModelId = existingModels.first(where: { $0.url == urls.first })?.id?.uuidString }

      NotificationCenter.default.post(name: NSNotification.Name("selectedLocalModelDidChange"), object: selectedModelId)
      NotificationCenter.default.post(name: NSNotification.Name("needStartNewConversation"), object: selectedModelId)
    } catch {
      print("error saving model:", error)
    }
  }
}
