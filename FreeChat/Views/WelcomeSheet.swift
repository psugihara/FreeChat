//
//  WelcomeSheet.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/28/23.
//

import SwiftUI

struct WelcomeSheet: View {
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: false)]
  )
  private var models: FetchedResults<Model>
  
  @Binding var isPresented: Bool
  @State var showModels = false
  
  @Environment(\.managedObjectContext) private var viewContext
  @AppStorage("selectedModelId") private var selectedModelId: String = Model.unsetModelId
  
  @StateObject var downloadManager = DownloadManager.shared
  
  
  var body: some View {
    VStack {
      Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
      Text("Welcome to FreeChat").font(.largeTitle)
      Text("Download a model to get started")
        .font(.title3)
      Text("Models are trained on different datasets, so each one has a unique personality and expertise. You can change models based on what you want to chat about.\n\nThe default model is general purpose, small, and works on most computers. Larger models are slower but wiser. Some models specialize in certain tasks like coding Python. FreeChat is compatible with most models in GGUF format. [Find new models](https://huggingface.co/models?search=GGUF)")
        .font(.callout)
        .lineLimit(10)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 16)

      ForEach(downloadManager.tasks, id: \.self) { t in
        ProgressView(t.progress).padding(5)
      }

      if downloadManager.tasks.count == 0 {
        Button(action: downloadDefault) {
          HStack {
            Text("Download default model")
            Text("2.96 GB").foregroundStyle(.white.opacity(0.7))
          }.padding(.horizontal, 20)
        }
        .keyboardShortcut(.defaultAction)
        .controlSize(.large)
        .padding(.top, 6)
        .padding(.horizontal)
        
        Button("Load custom model") {
          showModels = true
        }.buttonStyle(.link)
          .padding(.top, 4)
          .font(.callout)
      } else {
        Button("Continue") {
          isPresented = false
        }
        .controlSize(.large)
        .padding(.top, 6)
        .padding(.horizontal)
        .disabled(models.count == 0)
      }
    }
    .interactiveDismissDisabled()
    .frame(maxWidth: 480)
    .padding(.vertical, 40)
    .padding(.horizontal, 50)
    .sheet(isPresented: $showModels) {
      EditModels(selectedModelId: $selectedModelId)
    }
  }
  
  private func downloadDefault() {
    downloadManager.viewContext = viewContext
//    if let url = URL(string: "https://huggingface.co/TheBloke/Spicyboros-7B-2.2-GGUF/resolve/main/README.md") {
//    if let url = URL(string: "https://huggingface.co/TheBloke/Spicyboros-7B-2.2-GGUF/resolve/main/spicyboros-7b-2.2.Q3_K_S.gguf") {
    downloadManager.startDownload(url: Model.defaultModelUrl)
  }
}

#Preview {
  @State var isPresented: Bool = true
  @StateObject var conversationManager = ConversationManager.shared
  
  return WelcomeSheet(isPresented: $isPresented)
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(conversationManager)
  
}
