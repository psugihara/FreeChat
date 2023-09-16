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
  @AppStorage("firstLaunchComplete") private var firstLaunchComplete = false
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)]
  )
  private var models: FetchedResults<Model>

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: true)]
  )
  private var conversations: FetchedResults<Conversation>


  @State private var selection: Set<Conversation> = Set()
  @State private var showDeleteConfirmation = false
  
  @State var agent: Agent?
  
  @StateObject var conversationManager = ConversationManager()
  
  var body: some View {
    NavigationSplitView {
      NavList(selection: $selection, showDeleteConfirmation: $showDeleteConfirmation)
        .navigationSplitViewColumnWidth(ideal: 160)
    } detail: {
      if conversationManager.hasConversation(), agent != nil {
        ConversationView(agent: agent!).environmentObject(conversationManager)
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
    .onChange(of: systemPrompt) { nextPrompt in rebootAgent(systemPrompt: nextPrompt) }
    .onChange(of: selectedModelId) { nextModelId in rebootAgent(selectedModelId: nextModelId) }
    .onAppear { rebootAgent() }
    .onAppear(perform: initializeFirstLaunchData)
    .onChange(of: selection) { nextSelection in
      if nextSelection.first != nil {
        conversationManager.currentConversation =  nextSelection.first!
      } else {
        conversationManager.unsetConversation()
      }
    }
  }
  
  private func initializeFirstLaunchData() {
    if firstLaunchComplete { return }
    do {
      let c = try Conversation.create(ctx: viewContext)
      selection.insert(c)
    } catch (let error) {
      print("error creating initial conversation", error.localizedDescription)
    }
    firstLaunchComplete = true
  }
  
  private func rebootAgent(systemPrompt: String? = nil, selectedModelId: String? = nil) {
    let prompt = systemPrompt ?? self.systemPrompt
    let modelId = selectedModelId ?? self.selectedModelId
    let model = models.first { i in i.id?.uuidString == modelId }
    let url = model?.url == nil ? LlamaServer.DEFAULT_MODEL_URL : model!.url!
    
    Task {
      await agent?.llama.stopServer()
      agent = Agent(id: "Llama", prompt: agent?.prompt ?? "", systemPrompt: prompt, modelPath: url.path)
      await agent?.warmup()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    let context = PersistenceController.preview.container.viewContext
    ContentView().environment(\.managedObjectContext, context)
  }
}
