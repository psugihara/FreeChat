//
//  SettingsView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/6/23.
//

import SwiftUI

struct SettingsView: View {
  private static let defaultModelId = "default"
  
  @Environment(\.managedObjectContext) private var viewContext
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Model>
  
  @AppStorage("selectedModelId") private var selectedModelId: String = SettingsView.defaultModelId
  @AppStorage("systemPrompt") private var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  
  @State private var pendingSystemPrompt = ""
  private var systemPromptPendingSave: Bool {
    pendingSystemPrompt != "" && pendingSystemPrompt != systemPrompt
  }
  @State private var didSaveSystemPrompt = false
  
  @State var showModelHelp = false
  @State var showFileImporter = false
  
  var modelHeader: some View {
    HStack {
      Text("Model")
      Button(action: {
        showModelHelp = !showModelHelp
      }) {
        Image(systemName: showModelHelp ?  "questionmark.circle.fill" : "questionmark.circle")
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showModelHelp) {
        VStack(alignment: .leading) {
          Text("The model is FreeChat's brain. FreeChat comes with a general purpose small (7B) model that works on most computers. Larger models are slower but smarter. Some models specialize in certain tasks like coding Python. If you have a powerful machine, you should try a larger model. FreeChat is compatible with most models in GGUF format.")
            .fixedSize(horizontal: false, vertical: true)
          
          Text("Where can I find models?").padding(.top).font(.title3)
          Text("New models are being trained every day.")
          Link("Find them on HuggingFace",
               destination: URL(string: "https://huggingface.co/models?search=GGUF")!)
          
        }.padding()
          .frame(width: 400)
      }
    }
  }
  
  var body: some View {
    Form {
      Section("System prompt") {
        ZStack {
          TextEditor(text: $pendingSystemPrompt)
            .onAppear {
              pendingSystemPrompt = systemPrompt
            }
            .frame(height: 120)
            .padding(5)
          
          Group {
            if systemPromptPendingSave {
              Button("Save") {
                systemPrompt = pendingSystemPrompt
                didSaveSystemPrompt = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                  didSaveSystemPrompt = false
                }
              }
            } else if didSaveSystemPrompt {
              Image(systemName: "checkmark.circle.fill")
            } else {
              Spacer()
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(4)
        }
        .background(Color("TextBackground"))
      }
      .help("Customize chat behavior and personality")

      Spacer().padding()
      
      Section(header: modelHeader) {
        List(selection: $selectedModelId) {
          ForEach(items) { i in
            Text(i.name ?? i.url?.lastPathComponent ?? "Untitled").tag(i.id?.uuidString ?? "")
              .help(i.url?.path ?? "Unknown path")
          }
          Text("Default").tag(SettingsView.defaultModelId)
        }
        .listStyle(.automatic)
        .onDeleteCommand(perform: deleteSelected)
        
        Button(action: {
          showFileImporter = true
        }) {
          Image(systemName: "folder.circle")
          Text("Add custom model (.gguf)")
        }
        .fileImporter(
          isPresented: $showFileImporter,
          allowedContentTypes: [.data]
        ) { result in
          switch result {
            case .success(let fileURL):
              // gain access to the directory
              let gotAccess = fileURL.startAccessingSecurityScopedResource()
              if !gotAccess { return }
              
              do {
                let model = Model(context: viewContext)
                model.id = UUID()
                model.name = fileURL.lastPathComponent
                model.bookmark = try fileURL.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
                try viewContext.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  selectedModelId = model.id!.uuidString
                }
              } catch (let error) {
                print("error creating Model", error.localizedDescription)
              }
              // release access
              fileURL.stopAccessingSecurityScopedResource()
            case .failure(let error):
              // handle error
              print(error)
          }
          
        }
        
      }
      
    }.padding(20)
  }
  
  
  private func deleteSelected() {
    let model = items.first(where: { m in m.id?.uuidString == selectedModelId })
    if model != nil {
      viewContext.delete(model!)
      selectedModelId = SettingsView.defaultModelId
    }
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
