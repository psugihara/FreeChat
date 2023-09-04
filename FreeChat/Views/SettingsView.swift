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
    
  var body: some View {
    Form {
      LabeledContent("System Prompt") {
        Text(systemPrompt)
          .font(.subheadline)
          .multilineTextAlignment(.leading)
          .lineLimit(4)
          .frame(height: 40)
          .padding(.trailing)
        
        Button(action: {
          editSystemPrompt.toggle()
        }, label: {
          Text("Edit")
        })
        
      }.padding(.bottom, 12)
      
      if pickedModel != "" {
        Picker("Model", selection: $pickedModel) {
          Text("Default").tag(SettingsView.defaultModelId)
          ForEach(models) { i in
            Text(i.name ?? i.url?.lastPathComponent ?? "Untitled").tag(i.id?.uuidString ?? "")
              .help(i.url?.path ?? "Unknown path")
          }
          
          Divider()
          Text("Customize models...").tag(SettingsView.customizeModelsId)
        }.onReceive(Just(pickedModel)) { _ in
          if pickedModel == SettingsView.customizeModelsId {
            customizeModels = true
            pickedModel = selectedModelId
          } else {
            selectedModelId = pickedModel
          }
        }
      }
    }
    .sheet(isPresented: $customizeModels, onDismiss: dismissCustomizeModels) {
      EditModels()
    }
    .sheet(isPresented: $editSystemPrompt, onDismiss: dismissEditSystemPrompt) {
      EditSystemPrompt()
    }
    .padding(16)
    .navigationTitle("Settings")
    .onAppear {
      pickedModel = selectedModelId
    }
    .frame(idealWidth: 300)
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
