//
//  Persistence.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import CoreData

struct PersistenceController {
  static let shared = PersistenceController()
  
  static var preview: PersistenceController = {
    let result = PersistenceController(inMemory: true)
    let viewContext = result.container.viewContext
    for _ in 0..<10 {
      let newConversation = Conversation(context: viewContext)
      newConversation.createdAt = Date()
    }
    let model = Model(context: viewContext)
    let _ = SystemPrompt(context: viewContext)
    let _ = Message(context: viewContext)
    do {
      try viewContext.save()
      viewContext.delete(model)
    } catch {
      let nsError = error as NSError
      print("Error creating preview conversations \(nsError), \(nsError.userInfo)")
    }
    return result
  }()
  
  let container: NSPersistentCloudKitContainer
  
  init(inMemory: Bool = false) {
    container = NSPersistentCloudKitContainer(name: "Chats")
    if inMemory {
      container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
    }
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        /*
         Typical reasons for an error here include:
         * The parent directory does not exist, cannot be created, or disallows writing.
         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
         * The device is out of space.
         * The store could not be migrated to the current model version.
         Check the error message to determine what the actual problem was.
         */
        print("Unresolved error \(error), \(error.userInfo)")
      }
    })
    container.viewContext.automaticallyMergesChangesFromParent = true
  }
}
