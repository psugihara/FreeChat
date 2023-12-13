//
//  ContentView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import CoreData
import KeyboardShortcuts
import AppKit

struct ContentView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.openWindow) private var openWindow

  @AppStorage("systemPrompt") private var systemPrompt: String = Agent.DEFAULT_SYSTEM_PROMPT
  @AppStorage("firstLaunchComplete") private var firstLaunchComplete = false

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: false)]
  )
  private var models: FetchedResults<Model>

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: true)]
  )
  private var conversations: FetchedResults<Conversation>


  @State private var selection: Set<Conversation> = Set()
  @State private var showDeleteConfirmation = false
  @State private var showWelcome = false

  var agent: Agent? {
    conversationManager.agent
  }

  @EnvironmentObject var conversationManager: ConversationManager

  var body: some View {
    NavigationSplitView {
      NavList(selection: $selection, showDeleteConfirmation: $showDeleteConfirmation)
        .navigationSplitViewColumnWidth(min: 160, ideal: 160)
    } detail: {
      if selection.count > 1 {
        Text("\(selection.count) conversations selected")
      } else if conversationManager.showConversation() {
        ConversationView()
      } else if conversations.count == 0 {
        Text("Hit ⌘N to start a conversation")
      } else {
        Text("Select a conversation")
      }
    }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { output in
      Task {
        await agent?.llama.stopServer()
      }
    })
      .onDeleteCommand { showDeleteConfirmation = true }
      .onAppear(perform: initializeFirstLaunchData)
      .onChange(of: selection) { nextSelection in
      if nextSelection.count == 1,
        let first = nextSelection.first {
        conversationManager.currentConversation = first
      } else {
        conversationManager.unsetConversation()
      }
    }
      .onChange(of: conversationManager.currentConversation) { nextCurrent in
      if conversationManager.showConversation(), !selection.contains(nextCurrent) {
        selection = Set([nextCurrent])
      }
    }
      .onChange(of: models.count, perform: handleModelCountChange)
      .sheet(isPresented: $showWelcome) {
      WelcomeSheet(isPresented: $showWelcome)
    }
  }

  private func handleModelCountChange(_ nextCount: Int) {
    showWelcome = showWelcome || nextCount == 0
  }

  private func initializeFirstLaunchData() {
    if !conversationManager.summonRegistered {
      KeyboardShortcuts.onKeyUp(for: .summonFreeChat) {
        NSApp.activate(ignoringOtherApps: true)
        conversationManager.newConversation(viewContext: viewContext, openWindow: openWindow)
      }
      conversationManager.summonRegistered = true
    }

    handleModelCountChange(models.count)

    if firstLaunchComplete { return }
    conversationManager.newConversation(viewContext: viewContext, openWindow: openWindow)
    firstLaunchComplete = true
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    let context = PersistenceController.preview.container.viewContext
    ContentView().environment(\.managedObjectContext, context)
  }
}
