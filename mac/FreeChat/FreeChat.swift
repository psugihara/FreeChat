//
//  MantrasApp.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import KeyboardShortcuts

@main
struct FreeChatApp: App {
  @Environment(\.openWindow) var openWindow
  @StateObject var conversationManager = ConversationManager.shared

  let persistenceController = PersistenceController.shared
  
  var body: some Scene {
    WindowGroup(id: "main") {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
        .environmentObject(conversationManager)
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Chat") {
          conversationManager.newConversation(viewContext: persistenceController.container.viewContext, openWindow: openWindow)
        }.keyboardShortcut(KeyboardShortcut("N"))
      }
      SidebarCommands()
      CommandGroup(after: .windowList, addition: {
        Button("Conversations") {
          conversationManager.bringConversationToFront(openWindow: openWindow)
        }.keyboardShortcut(KeyboardShortcut("0"))
      })
    }

    
#if os(macOS)
    Settings {
      SettingsView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
        .environmentObject(conversationManager)
    }
    .windowResizability(.contentSize)
#endif
  }
}
