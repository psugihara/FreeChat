//
//  SettingsView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/6/23.
//

import SwiftUI

struct SettingsView: View {
  private static let defaultModelId = "default"
  private static let customModelId = "custom"
  
  @Environment(\.managedObjectContext) private var viewContext
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Model>
  
//  @AppStorage("modelURLBookmark") private var modelURLBookmark: Data?
  
  @AppStorage("selectedModelId2") private var selectedModelId: String = SettingsView.defaultModelId
  
  
  var selectedModel: Model? {
    items.first { i in i.id?.uuidString == selectedModelId }
  }
  
//  @State var selectedModelId: UUID = defaul

//  var modelURL: URL {
//    var stale = false
//    do {
//      if selectedModel == nil { return LlamaServer.DEFAULT_MODEL_URL }
//      let res = try URL(resolvingBookmarkData: selectedModel!.bookmark!, options: .withSecurityScope, bookmarkDataIsStale: &stale)
//      return res
//    } catch (let error){
//      print("Error resolving model bookmark", error.localizedDescription)
//      return LlamaServer.DEFAULT_MODEL_URL
//    }
//  }
  
  @State var showFileImporter = false
  
  var body: some View {
    Form {
      Picker("Model", selection: $selectedModelId) {
        ForEach(items) { item in
          Text(item.name ?? item.url?.lastPathComponent ?? "Untitled").tag(item.id?.uuidString ?? SettingsView.defaultModelId)
        }
        Text("Default (Llama 2 7B chat)").tag(SettingsView.defaultModelId)
        Label("Add custom model (.bin)", systemImage: "folder.circle").tag(SettingsView.customModelId)
      }
      .onChange(of: selectedModelId) { newSelected in
        print("change", newSelected)
        if newSelected == SettingsView.customModelId {
          showFileImporter = true
        } else {
          showFileImporter = false
        }
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
            print("gotaccess", gotAccess)
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
    .padding(20)
    .frame(width: 350, height: 100)
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
