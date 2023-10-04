//
//  SettingsView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/6/23.
//

import SwiftUI
import Combine
import KeyboardShortcuts

struct SettingsView: View {
  static let title = "Settings"
  private static let customizeModelsId = "customizeModels"
  
  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject var conversationManager: ConversationManager
  
  // TODO: add dropdown like models for storing multiple system prompts?
  //  @FetchRequest(
  //    sortDescriptors: [NSSortDescriptor(keyPath: \SystemPrompt.updatedAt, ascending: true)],
  //    animation: .default)
  //  private var systemPrompts: FetchedResults<SystemPrompt>
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>
  
  @AppStorage("selectedModelId") private var selectedModelId: String = Model.unsetModelId
  @AppStorage("systemPrompt") private var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  
  @State var pickedModel: String = Model.unsetModelId
  @State var customizeModels = false
  @State var editSystemPrompt = false
  
  var globalHotkey: some View {
    KeyboardShortcuts.Recorder("Summon chat", name: .summonFreeChat)
  }
  
  var systemPromptEditor: some View {
    LabeledContent("System prompt") {
      ZStack(alignment: .topTrailing) {
        HStack {
          Text(systemPrompt)
            .font(.callout)
            .multilineTextAlignment(.leading)
            .lineLimit(6, reservesSpace: false)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        Button(action: {
          editSystemPrompt.toggle()
        }, label: {
          Text("Customize")
        })
        .padding(.leading, 10)
        .padding(.top, -22.0)
      }.frame(maxWidth: .infinity)
    }
  }
  
  var modelPicker: some View {
    VStack(alignment: .leading) {
      Picker("Model", selection: $pickedModel) {
        ForEach(models) { i in
          Text(i.name ?? i.url?.lastPathComponent ?? "Untitled").tag(i.id?.uuidString ?? "")
            .help(i.url?.path ?? "Unknown path")
        }
        
        Divider().tag(Model.unsetModelId)
        Text("Add or remove models...").tag(SettingsView.customizeModelsId)
      }.onReceive(Just(pickedModel)) { _ in
        if pickedModel == SettingsView.customizeModelsId {
          customizeModels = true
          pickedModel = selectedModelId
        } else {
          selectedModelId = pickedModel
        }
      }
      
      Text("The default model is general purpose, small, and works on most computers. Larger models are slower but wiser. Some models specialize in certain tasks like coding Python. FreeChat is compatible with most models in GGUF format. [Find new models](https://huggingface.co/models?search=GGUF)")
        .font(.callout)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
        .lineLimit(5)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
  
  var body: some View {
    Form {
      globalHotkey
      systemPromptEditor
      modelPicker
    }
    .formStyle(.grouped)
    .sheet(isPresented: $customizeModels) {
      EditModels(selectedModelId: $selectedModelId)
    }
    .sheet(isPresented: $editSystemPrompt) {
      EditSystemPrompt()
    }
    .navigationTitle(SettingsView.title)
    .onAppear {
      pickedModel = selectedModelId
    }
    .onChange(of: selectedModelId) { newModelId in
      pickedModel = newModelId
      var model: Model?
      if newModelId == Model.unsetModelId {
        model = models.first
      } else {
        model = models.first { i in i.id?.uuidString == newModelId }
      }

      conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
    }
    .onChange(of: systemPrompt) { nextPrompt in
      let model = models.first { i in i.id?.uuidString == selectedModelId }
      conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
    }
    .frame(minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400, alignment: .center)
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
