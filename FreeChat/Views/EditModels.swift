//
//  CustomizeModelsView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/3/23.
//

import SwiftUI

struct EditModels: View {
  private static let defaultModelId = "default"
  
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.dismiss) var dismiss

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Model>
  
  @State private var selectedModelId: String = EditModels.defaultModelId
  @State var showFileImporter = false
  @State var showModelHelp = false
  
  var plusMinusToolbar: some View {
    HStack {
      Button(action: {
        showFileImporter = true
      }) {
        Image(systemName: "plus").padding(6)
      }
      .padding(.leading, 10)
      .buttonStyle(.plain)
      .help("Add custom model (.gguf file)")
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
      
      Button(action: deleteSelected) {
        Image(systemName: "minus").padding(6)
      }.buttonStyle(.plain)
        .disabled(selectedModelId == EditModels.defaultModelId)
    }
    .frame(maxWidth: .infinity, maxHeight: 32, alignment: .leading)
  }
  
  var modelHeader: some View {
    HStack {
      Text("Models")
      Button(action: {
        showModelHelp.toggle()
      }) {
        Image(systemName: showModelHelp ?  "questionmark.circle.fill" : "questionmark.circle")
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showModelHelp) {
        VStack(alignment: .leading) {
          Text("The default model is general purpose, small (7B), and works on most computers. Larger models are slower but smarter. Some models specialize in certain tasks like coding Python. FreeChat is compatible with most models in GGUF format.")
            .fixedSize(horizontal: false, vertical: true)
          Link("Find new models",
               destination: URL(string: "https://huggingface.co/models?search=GGUF")!)
          
        }.padding()
          .frame(width: 400)
      }
    }
    .padding(.top, 10)
    .frame(maxWidth: .infinity, alignment: .center)
  }
  
  
  var body: some View {
    Form {
      modelHeader
      List(selection: $selectedModelId) {
        Text("Default").tag(EditModels.defaultModelId)
        ForEach(items) { i in
          Text(i.name ?? i.url?.lastPathComponent ?? "Untitled").tag(i.id?.uuidString ?? "")
            .help(i.url?.path ?? "Unknown path")
            .contextMenu { Button(action: {
              deleteModel(i)
            }) {
              Label("Delete Model", systemImage: "trash")
            } }.tag(i.id?.uuidString ?? "")
        }
      }
      .onDeleteCommand(perform: deleteSelected)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        plusMinusToolbar
      }
      HStack {
        Button("Done") {
          dismiss()
        }
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding()
    .frame(width: 400, height: 300)
  }
  
  private func deleteSelected() {
    let model = items.first(where: { m in m.id?.uuidString == selectedModelId })
    if model != nil {
      deleteModel(model!)
    }
  }
  
  private func deleteModel(_ model: Model) {
    viewContext.delete(model)
    selectedModelId = EditModels.defaultModelId
  }
}

struct EditModels_Previews: PreviewProvider {
  static var previews: some View {
    EditModels().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
