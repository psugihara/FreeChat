//
//  MantrasApp.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI

@main
struct FreeChatApp: App {
  let persistenceController = PersistenceController.shared
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Chat") {
          _ = try? Conversation.create(ctx: persistenceController.container.viewContext)
        }.keyboardShortcut(KeyboardShortcut("N"))
      }
      SidebarCommands()
    }
#if os(macOS)
    Settings {
      SettingsView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
    .windowResizability(.contentSize)
#endif
  }
}
