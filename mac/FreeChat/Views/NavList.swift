//
//  ConversationNavItem.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//

import SwiftUI

struct NavList: View {
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject var conversationManager: ConversationManager

  @State private var folderHierarchy: [FolderNode] = []
  @State private var rootConversations: [Conversation] = []
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)],
    animation: .default)
  private var items: FetchedResults<Conversation>

  @Binding var selection: Set<Conversation>
  @Binding var showDeleteConfirmation: Bool

  @State var editing: Conversation?
  @State var newTitle = ""
  @FocusState var fieldFocused
  
  @State private var refreshTrigger = UUID()

  var body: some View {
    List {
                ForEach(folderHierarchy) { node in
                    FolderView(node: node, selection: $selection, refreshTrigger: $refreshTrigger)
                        .onDrop(of: [.text], delegate: FolderDropDelegate(folder: node.folder, refreshTrigger: $refreshTrigger))
                }
                ForEach(rootConversations) { conversation in
                    ConversationRow(conversation: conversation, selection: $selection)
                        .draggable(conversation.objectID.uriRepresentation().absoluteString)
                }
            }
            .onAppear(perform: refreshHierarchy)
            .onChange(of: refreshTrigger) { _ in
                refreshHierarchy()
            }
    /*
    List(items, id: \.self, selection: $selection) { item in
      if editing == item {
        TextField(item.titleWithDefault, text: $newTitle)
          .textFieldStyle(.plain)
          .focused($fieldFocused)
          .onSubmit {
          saveNewTitle(conversation: item)
        }
          .onExitCommand {
          editing = nil
        }
          .onChange(of: fieldFocused) { focused in
          if !focused {
            editing = nil
          }
        }
          .padding(.horizontal, 4)
      } else {
        Text(item.titleWithDefault).padding(.leading, 4)
      }
    }
    */
    
    .frame(minWidth: 50)
      .toolbar {
      ToolbarItem {
        Spacer()
      }
      ToolbarItem {
        Button(action: newConversation) {
          Label("Add conversation", systemImage: "plus")
        }
      }
        ToolbarItem {
          Button(action: createFolder) {
            Label("New Folder", systemImage: "folder")
          }
        }
    }
      .onChange(of: items.count) { _ in
      selection = Set([items.first].compactMap { $0 })
    }
      .contextMenu(forSelectionType: Conversation.self) { _ in
      Button {
        deleteSelectedConversations()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    } primaryAction: { items in
      if items.count > 1 { return }
      editing = items.first
      fieldFocused = true
    }
      .confirmationDialog("Are you sure you want to delete \(selection.count == 1 ? "this" : "\(selection.count)") conversation\(selection.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
      Button("Yes, delete") {
        deleteSelectedConversations()
      }
        .keyboardShortcut(.defaultAction)
    }
    
    
    
    
  }//body
  
  private func refreshHierarchy() {
      let hierarchyManager = ConversationHierarchy(viewContext: viewContext)
      (folderHierarchy, rootConversations) = hierarchyManager.getHierarchy()
      refreshTrigger = UUID() // This will trigger a view update
  }

  private func saveNewTitle(conversation: Conversation) {
    conversation.title = newTitle
    newTitle = ""
    do {
      try viewContext.save()

      // HACK: trigger a state change so the title will refresh the title bar
      selection.remove(conversation)
      selection.insert(conversation)
    } catch {
      let nsError = error as NSError
      print("Unresolved error \(nsError), \(nsError.userInfo)")
    }
  }

  private func deleteSelectedConversations() {
    withAnimation {
      selection.forEach(viewContext.delete)
      do {
        try viewContext.save()
        selection.removeAll()
        if items.count > 0 {
          selection.insert(items.first!)
        }
      } catch {
        let nsError = error as NSError
        print("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }

  private func deleteConversation(conversation: Conversation) {
    withAnimation {
      viewContext.delete(conversation)
      do {
        try viewContext.save()
      } catch {
        let nsError = error as NSError
        print("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }

  private func sortedItems() -> [Conversation] {
    items.sorted(by: { $0.updatedAt!.compare($1.updatedAt!) == .orderedDescending })
  }

  private func newConversation() {
    conversationManager.newConversation(viewContext: viewContext, openWindow: openWindow)
  }
  
  private func createFolder() {
    let folderName = "New Folder"
    print("want to create folder")
    do {
           _ = try Folder.create(ctx: viewContext, name: folderName)
          print("Folder created")
          debugPrintAllFolders()
        refreshHierarchy()
          
       } catch {
           print("An error occurred while creating the new folder: \(error)")
       }
  }
  
  private func debugPrintAllFolders(){
    // Fetch all folders after creating a new one
    // To confirm the data model is working
    let request: NSFetchRequest<Folder> = Folder.fetchRequest()
    do {
        let results = try viewContext.fetch(request)
        print("Fetched Folders:")
        for folder in results {
            print(folder.name ?? "")
        }
    } catch {
        print("Failed to fetch folders: \(error)")
    }
  }
  
}


struct FolderView: View {
    let node: FolderNode
    @Binding var selection: Set<Conversation>
    @Binding var refreshTrigger: UUID

    var body: some View {
        DisclosureGroup(
            content: {
                ForEach(node.subfolders) { subfolder in
                    FolderView(node: subfolder, selection: $selection, refreshTrigger: $refreshTrigger)
                }
                ForEach(node.conversations) { conversation in
                    ConversationRow(conversation: conversation, selection: $selection)
                }
            },
            label: {
                Text(node.folder.name ?? "Unnamed Folder")
            }
        )
        .onDrop(of: [.text], delegate: FolderDropDelegate(folder: node.folder, refreshTrigger: $refreshTrigger))
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    @Binding var selection: Set<Conversation>
    
    var body: some View {
        Text(conversation.titleWithDefault)
            .padding(.leading, 4)
            .draggable(conversation.objectID.uriRepresentation().absoluteString)
            .onTapGesture {
                selection = [conversation]
            }
    }
}

struct FolderDropDelegate: DropDelegate {
    let folder: Folder
    @Binding var refreshTrigger: UUID

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadObject(ofClass: String.self) { (string, error) in
            DispatchQueue.main.async {
                if let uriString = string,
                   let url = URL(string: uriString),
                   let objectID = self.folder.managedObjectContext?.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
                   let conversation = try? self.folder.managedObjectContext?.existingObject(with: objectID) as? Conversation {
                    conversation.moveToFolder(self.folder)
                    try? self.folder.managedObjectContext?.save()
                    self.refreshTrigger = UUID() // This will trigger a view update
                }
            }
        }
        return true
    }
}



#if DEBUG
  struct NavList_Previews_Container: View {
    @State public var selection: Set<Conversation> = Set()
    @State public var showDeleteConfirmation = false

    var body: some View {
      NavList(selection: $selection, showDeleteConfirmation: $showDeleteConfirmation)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
  }

  struct NavList_Previews: PreviewProvider {
    static var previews: some View {
      NavList_Previews_Container()
    }
  }
#endif
