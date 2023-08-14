//
//  ContentView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import CoreData

struct ContentView: View {
  @Environment(\.managedObjectContext) private var viewContext

  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("systemPrompt") private var systemPrompt: String = Agent.DEFAULT_SYSTEM_PROMPT
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)],
    animation: .default
  )
  private var models: FetchedResults<Model>

  
  @State private var selection: Set<Conversation> = Set()
  @State private var showDeleteConfirmation = false
  
  @State var agent: Agent?
  
  var body: some View {
    NavigationSplitView {
      NavList(selection: $selection)
    } detail: {
      if selection.count == 1, agent != nil {
        ConversationView(conversation: selection.first!, agent: agent!)
      } else {
        Text("Select a conversation")
      }
    }
    .navigationTitle(selection.count == 1 ? selection.first!.titleWithDefault : "Chats")
    .navigationSplitViewColumnWidth(50)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { output in
      agent?.llama.stopServer()
    })
    .backgroundStyle(.ultraThinMaterial)
    .onDeleteCommand { showDeleteConfirmation = true }
    .confirmationDialog("Are you sure you want to delete \(selection.count == 1 ? "this" : "\(selection.count)") conversation\(selection.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
      Button("Yes, delete", role: .destructive) {
        deleteSelectedConversations()
      }
      .keyboardShortcut(.defaultAction)
      
    }
    .onChange(of: systemPrompt) { _ in rebootAgent() }
    .onChange(of: selectedModelId) { _ in rebootAgent() }
    .onAppear(perform: rebootAgent)
  }
  
  private func rebootAgent() {
    Task {
      let model = models.first { i in i.id?.uuidString == selectedModelId }
      let url = model?.url == nil ? LlamaServer.DEFAULT_MODEL_URL : model!.url!
      
      agent = Agent(id: "Llama", prompt: agent?.prompt ?? "", systemPrompt: systemPrompt, modelPath: url.path)
      await agent?.warmup()
    }
  }
  
  private func deleteSelectedConversations() {
    withAnimation {
      selection.forEach(viewContext.delete)
      do {
        try viewContext.save()
        selection = Set()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
#endif
