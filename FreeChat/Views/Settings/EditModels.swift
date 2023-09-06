//
//  CustomizeModelsView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/3/23.
//

import SwiftUI

struct EditModels: View {
  @Environment(\.colorScheme) var colorScheme
  
  static let formatErrorText = "Model files must be in .gguf format"
  private static let defaultModelId = "default"
  
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.dismiss) var dismiss
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Model>
  
  @State private var selectedModelId: String = EditModels.defaultModelId
  @State var showFileImporter = false
  @State var errorText = ""
  
  var bottomToolbar: some View {
    VStack(spacing: 0) {
      Rectangle()
        .frame(maxWidth: .infinity, maxHeight: 1)
        .foregroundColor(Color(NSColor.gridColor))
      HStack {
        Button(action: {
          showFileImporter = true
        }) {
          Image(systemName: "plus").padding(.horizontal, 6)
        }
        .frame(maxHeight: .infinity)
        .padding(.leading, 10)
        .buttonStyle(.borderless)
        .help("Add custom model (.gguf file)")
        .fileImporter(
          isPresented: $showFileImporter,
          allowedContentTypes: [.data],
          onCompletion: importModel
        )
        
        Button(action: deleteSelected) {
          Image(systemName: "minus").padding(.horizontal, 6)
        }
        .frame(maxHeight: .infinity)
        .buttonStyle(.borderless)
        .disabled(selectedModelId == EditModels.defaultModelId)
        
        Spacer()
        if !errorText.isEmpty {
          Text(errorText).foregroundColor(.red)
        }
        Spacer()
        Button("Done") {
          dismiss()
        }.padding(.horizontal, 10).keyboardShortcut(.defaultAction)
          .buttonStyle(.borderless)
      }
      .frame(maxWidth: .infinity, maxHeight: 27, alignment: .leading)
    }
    .background(Material.bar)
  }
  
  var modelList: some View {
    List(selection: $selectedModelId) {
      Section("Models") {
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
    }
    .listStyle(.inset(alternatesRowBackgrounds: true))
    .onDeleteCommand(perform: deleteSelected)
  }
  
  var body: some View {
    VStack(spacing: 0) {
      modelList
      bottomToolbar
    }.frame(width: 400, height: 270)
  }
  
  private func deleteSelected() {
    errorText = ""
    let model = items.first(where: { m in m.id?.uuidString == selectedModelId })
    if model != nil {
      deleteModel(model!)
    }
  }
  
  private func deleteModel(_ model: Model) {
    errorText = ""
    viewContext.delete(model)
    selectedModelId = EditModels.defaultModelId
  }
  
  private func importModel(result: Result<URL, Error>) {
    errorText = ""

    switch result {
      case .success(let fileURL):
        if fileURL.pathExtension != "gguf" {
          print("ext", fileURL.pathExtension)
          errorText = EditModels.formatErrorText
          return
        }
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

struct EditModels_Previews: PreviewProvider {
  static var previews: some View {
    EditModels().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    EditModels(errorText: EditModels.formatErrorText).previewDisplayName("Edit Models Error")
  }
}
