//
//  CustomizeModelsView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/3/23.
//

import SwiftUI
import UniformTypeIdentifiers.UTType

struct EditModels: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var conversationManager: ConversationManager

  @Binding var selectedModelId: String?

  // list state
  @State var editingModelId: String? // Highlight selection in the list
  @State var hoveredModelId: String?

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: false)],
    animation: .default)
  private var items: FetchedResults<Model>

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
            .frame(maxHeight: .infinity)
        }
          .frame(maxHeight: .infinity)
          .padding(.leading, 10)
          .buttonStyle(.borderless)
          .help("Add custom model (.gguf file)")
          .background(Color.white.opacity(0.0001))
          .fileImporter(
          isPresented: $showFileImporter,
          allowedContentTypes: [UTType("com.npc-pet.Chats.gguf") ?? .data],
          allowsMultipleSelection: true,
          onCompletion: importModel
        )

        Button(action: deleteEditing) {
          Image(systemName: "minus").padding(.horizontal, 6)
            .frame(maxHeight: .infinity)
        }
          .frame(maxHeight: .infinity)
          .buttonStyle(.borderless)
          .disabled(editingModelId == nil)

        Spacer()
        if !errorText.isEmpty {
          Text(errorText).foregroundColor(.red)
        }
        Spacer()
        Button("Select") {
          selectEditing()
        }
          .keyboardShortcut(.return, modifiers: [])
          .frame(width: 0)
          .hidden()
        Button("Done") {
          dismiss()
        }.padding(.horizontal, 10).keyboardShortcut(.escape)
      }
        .frame(maxWidth: .infinity, maxHeight: 27, alignment: .leading)
    }
      .background(Material.bar)
  }

  func modelListItem(_ i: Model, url: URL) -> some View {
    let loading = conversationManager.loadingModelId != nil && conversationManager.loadingModelId == i.id?.uuidString
    return HStack {
      Group {
        if loading {
          ProgressView().controlSize(.small)
        } else {
          Text("✓").bold().opacity(selectedModelId == i.id?.uuidString ? 1 : 0)
        }
      }.frame(width: 20)
      Text(i.name ?? url.lastPathComponent).tag(i.id?.uuidString ?? "")
      if i.size != 0 {
        Text("\(String(format: "%.2f", Double(i.size) / 1000.0)) GB")
          .foregroundColor(.secondary)
      }
      Spacer()
      if !loading, i.error != nil, !i.error!.isEmpty {
        Label(i.error!, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .accentColor(.red)
      }
      hoverSelect(i.id?.uuidString ?? "", loading: loading)
    }.tag(i.id?.uuidString ?? "")
      .padding(4)
      .onHover { hovered in
      if hovered {
        hoveredModelId = i.id?.uuidString
      } else if hoveredModelId == i.id?.uuidString {
        hoveredModelId = nil
      }
    }
  }

  func hoverSelect(_ modelId: String, loading: Bool = false) -> some View {
    Button("Select") {
      selectedModelId = modelId
    }
    .opacity(hoveredModelId == modelId && selectedModelId != modelId ? 1 : 0)
    .disabled(hoveredModelId != modelId || loading || selectedModelId == modelId)
  }

  var modelList: some View {
    List(selection: $editingModelId) {
      Section("Models") {
        ForEach(items) { i in
          if let url = i.url {
            modelListItem(i, url: url)
              .help(url.path)
              .contextMenu {
              Button("Delete Model") { deleteModel(i) }
              Button("Show in Finder") { showInFinder(url) }
            }
          }
        }
      }
    }
      .listStyle(.inset(alternatesRowBackgrounds: true))
      .onDeleteCommand(perform: deleteEditing)
  }

  var body: some View {
    VStack(spacing: 0) {
      modelList
      bottomToolbar
    }.frame(width: 500, height: 290)
  }

  private func deleteEditing() {
    errorText = ""
    if let model = items.first(where: { m in m.id?.uuidString == editingModelId }) {
      deleteModel(model)
    }
  }

  private func showInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  private func selectEditing() {
    if editingModelId != nil {
      selectedModelId = editingModelId!
    }
  }

  private func deleteModel(_ model: Model) {
    errorText = ""
    viewContext.delete(model)
    do {
      try viewContext.save()
      if editingModelId == selectedModelId {
        selectedModelId = items.first?.id?.uuidString
      }
      editingModelId = nil
    } catch {
      print("error deleting model \(model)", error)
    }
  }

  private func importModel(result: Result<[URL], Error>) {
    errorText = ""

    switch result {
    case .success(let fileURLs):
      do {
        let insertedModels = try insertModels(from: fileURLs)
        selectedModelId = insertedModels.first?.id?.uuidString ?? selectedModelId
      } catch let error as ModelCreateError {
        errorText = error.localizedDescription
      } catch (let err) {
        print("Error creating model", err.localizedDescription)
      }
    case .failure(let error):
      // handle error
      print(error)
    }
  }

  private func insertModels(from fileURLs: [URL]) throws -> [Model] {
    var insertedModels = [Model]()
    for fileURL in fileURLs {
      guard nil == items.first(where: { $0.url == fileURL }) else { continue }
      insertedModels.append(try Model.create(context: viewContext, fileURL: fileURL))
    }

    return insertedModels
  }
}

struct EditModels_Previews_Container: View {
  @State var selectedModelId: String?
  var body: some View {
    EditModels(selectedModelId: $selectedModelId)
    EditModels(selectedModelId: $selectedModelId, errorText: ModelCreateError.unknownFormat.localizedDescription)
      .previewDisplayName("Edit Models Error")

  }
}

struct EditModels_Previews: PreviewProvider {
  static var previews: some View {

    let ctx = PersistenceController.preview.container.viewContext
    let c = try! Conversation.create(ctx: ctx)
    let cm = ConversationManager()
    cm.currentConversation = c
    cm.agent = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

    let question = Message(context: ctx)
    question.conversation = c
    question.text = "how can i check file size in swift?"

    let response = Message(context: ctx)
    response.conversation = c
    response.fromId = "llama"
    response.text = """
      Hi! You can use `FileManager` to get information about files, including their sizes. Here's an example of getting the size of a text file:
      ```swift
      let path = "path/to/file"
      do {
          let attributes = try FileManager.default.attributesOfItem(atPath: path)
          if let fileSize = attributes[FileAttributeKey.size] as? UInt64 {
              print("The file is \\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))")
          }
      } catch {
          // Handle any errors
      }
      ```
      """

    return EditModels_Previews_Container()
      .environment(\.managedObjectContext, ctx)
      .environmentObject(cm)
  }
}
