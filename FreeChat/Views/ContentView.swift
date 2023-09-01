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
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)]
  )
  private var models: FetchedResults<Model>
  

  @State private var selection: Set<Conversation> = Set()
  @State private var showDeleteConfirmation = false
  
  @State var agent: Agent?
  
  var body: some View {
    NavigationSplitView {
      NavList(selection: $selection, showDeleteConfirmation: $showDeleteConfirmation)
        .navigationSplitViewColumnWidth(ideal: 160)
    } detail: {
      if selection.count == 1, agent != nil {
        ConversationView(conversation: selection.first!, agent: agent!)
      } else {
        Text("Select a conversation")
      }
    }
    .navigationTitle(selection.count == 1 ? selection.first!.titleWithDefault : "FreeChat")
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { output in
      Task {
        await agent?.llama.stopServer()
      }
    })
    .onDeleteCommand { showDeleteConfirmation = true }
    .onChange(of: systemPrompt) { _ in rebootAgent() }
    .onChange(of: selectedModelId) { _ in rebootAgent() }
    .onAppear(perform: rebootAgent)
  }
  
  private func rebootAgent() {
    Task {
      let model = models.first { i in i.id?.uuidString == selectedModelId }
      let url = model?.url == nil ? LlamaServer.DEFAULT_MODEL_URL : model!.url!
      
      Task {
        await agent?.llama.stopServer()
        agent = Agent(id: "Llama", prompt: agent?.prompt ?? "", systemPrompt: systemPrompt, modelPath: url.path)
        await agent?.warmup()
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
