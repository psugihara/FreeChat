//
//  SettingsView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/6/23.
//

import SwiftUI
import Combine

struct SettingsView: View {
  private static let defaultModelId = "default"
  private static let customizeModelsId = "customizeModels"
  
  @Environment(\.managedObjectContext) private var viewContext
  
  // TODO: add dropdown like models for storing multiple system prompts?
  //  @FetchRequest(
  //    sortDescriptors: [NSSortDescriptor(keyPath: \SystemPrompt.updatedAt, ascending: true)],
  //    animation: .default)
  //  private var systemPrompts: FetchedResults<SystemPrompt>
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>
  
  @AppStorage("selectedModelId") private var selectedModelId: String = SettingsView.defaultModelId
  @AppStorage("systemPrompt") private var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  
  
  @State var pickedModel: String = ""
  @State var customizeModels = false
  @State var editSystemPrompt = false
  
  var systemPromptEditor: some View {
    LabeledContent("System prompt:") {
      VStack(alignment: .leading) {
        Text(systemPrompt)
          .font(.body)
          .multilineTextAlignment(.leading)
          .lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.trailing)
        
        Button(action: {
          editSystemPrompt.toggle()
        }, label: {
          Text("Edit prompt")
        })
      }
    }.padding(.bottom, 10)
  }
  
  var modelPicker: some View {
    LabeledContent("Model:") {
      VStack(alignment: .leading) {
        Picker("", selection: $pickedModel) {
          Text("Default").tag(SettingsView.defaultModelId)
          ForEach(models) { i in
            Text(i.name ?? i.url?.lastPathComponent ?? "Untitled").tag(i.id?.uuidString ?? "")
              .help(i.url?.path ?? "Unknown path")
          }
          
          Divider()
          Text("Add or remove models...").tag(SettingsView.customizeModelsId)
        }.onReceive(Just(pickedModel)) { _ in
          if pickedModel == SettingsView.customizeModelsId {
            customizeModels = true
            pickedModel = selectedModelId
          } else {
            selectedModelId = pickedModel
          }
        }.labelsHidden()
        
        Text("The default model is general purpose, small (7B), and works on most computers. Larger models are slower but smarter. Some models specialize in certain tasks like coding Python. FreeChat is compatible with most models in GGUF format.\n\n[Find new models](https://huggingface.co/models?search=GGUF)")
          .font(.caption)
          .lineLimit(5)
          .fixedSize(horizontal: false, vertical: true)
          .font(.footnote)
        .font(.footnote)
      }
    }
  }
  
  var body: some View {
      Form {
        systemPromptEditor
        if pickedModel != "" {
          modelPicker
        }
      }
      .sheet(isPresented: $customizeModels, onDismiss: dismissCustomizeModels) {
        EditModels()
      }
      .sheet(isPresented: $editSystemPrompt, onDismiss: dismissEditSystemPrompt) {
        EditSystemPrompt()
      }
      .padding(20)
      .navigationTitle("Settings")
      .onAppear {
        pickedModel = selectedModelId
      }
      .frame(maxWidth: 900, maxHeight: 300)

  }
  
  private func dismissEditSystemPrompt() {
    editSystemPrompt = false
  }
  
  private func dismissCustomizeModels() {
    customizeModels = false
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
