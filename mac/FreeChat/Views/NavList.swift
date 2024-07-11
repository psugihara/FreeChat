//
//  ConversationNavItem.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//



import SwiftUI
import CoreData

struct NavList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var conversationManager = ConversationManager()

    @State private var hierarchicalItems: [ListItem] = []
    @Binding var selection: Set<Conversation>
    @Binding var showDeleteConfirmation: Bool

    @State private var editingItem: ListItem?
    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool
    
    @State private var selectedFolder: Folder?
    @State private var refreshTrigger = UUID()

    var body: some View {
        List(hierarchicalItems, children: \.children) { item in
            HierarchicalItemRow(item: item,
                                selection: $selection,
                                editingItem: $editingItem,
                                newTitle: $newTitle,
                                fieldFocused: _fieldFocused,
                                selectedFolder: $selectedFolder)
        }
        .onAppear(perform: refreshItems)
        .onChange(of: refreshTrigger) { _ in refreshItems() }
        .frame(minWidth: 50)
        .toolbar {
            ToolbarItem { Spacer() }
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
        .confirmationDialog("Are you sure you want to delete \(selection.count == 1 ? "this" : "\(selection.count)") conversation\(selection.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
            Button("Yes, delete") {
                deleteSelectedConversations()
            }
            .keyboardShortcut(.defaultAction)
        }
        .onDisappear {
            // Cancel any ongoing operations or listeners
            // Reset any temporary state
            editingItem = nil
            newTitle = ""
        }
    }

  private func refreshItems() {
      DispatchQueue.main.async {
          do {
              // Fetch root folders
              let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
              folderFetchRequest.predicate = NSPredicate(format: "parent == nil")
              let rootFolders = try viewContext.fetch(folderFetchRequest)
              
              // Fetch root conversations (conversations not in any folder)
              let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
              conversationFetchRequest.predicate = NSPredicate(format: "folder == nil")
              let rootConversations = try viewContext.fetch(conversationFetchRequest)
              
              // Build the hierarchy
              self.hierarchicalItems = self.buildHierarchy(folders: rootFolders, conversations: rootConversations)
          } catch {
              print("Failed to fetch items: \(error)")
          }
      }
  }

  private func buildHierarchy(folders: [Folder], conversations: [Conversation]) -> [ListItem] {
      var items: [ListItem] = []
      
      // Add folders
      for folder in folders {
          let subfolders = folder.subfolders
          let folderConversations = Array(folder.conversation as? Set<Conversation> ?? [])
          let children = buildHierarchy(folders: subfolders, conversations: folderConversations)
          let item = ListItem(id: folder.objectID.uriRepresentation().absoluteString, item: folder, children: children)
          items.append(item)
      }
      
      // Add conversations
      for conversation in conversations {
          let item = ListItem(id: conversation.objectID.uriRepresentation().absoluteString, item: conversation, children: nil)
          items.append(item)
      }
      
      // Sort items (folders first, then conversations, both alphabetically)
      items.sort { (item1, item2) in
          if item1.isFolder && !item2.isFolder {
              return true
          } else if !item1.isFolder && item2.isFolder {
              return false
          } else {
              return item1.item.name?.lowercased() ?? "" < item2.item.name?.lowercased() ?? ""
          }
      }
      
      return items
  }

    private func newConversation() {
        do {
            let conversation = try Conversation.create(ctx: viewContext)
            conversation.folder = selectedFolder
            try viewContext.save()
            refreshTrigger = UUID()
        } catch {
            print("Error creating new conversation: \(error)")
        }
    }

    private func createFolder() {
        let folderName = "New Folder"
        do {
            let newFolder = try Folder.create(ctx: viewContext, name: folderName, parent: selectedFolder)
            try viewContext.save()
            refreshTrigger = UUID()
        } catch {
            print("An error occurred while creating the new folder: \(error)")
        }
    }

    private func deleteSelectedConversations() {
        DispatchQueue.main.async {
            withAnimation {
                selection.forEach(viewContext.delete)
                do {
                    try viewContext.save()
                    selection.removeAll()
                    refreshTrigger = UUID()
                } catch {
                    print("Error deleting conversations: \(error)")
                }
            }
        }
    }
}

struct HierarchicalItemRow: View {
    let item: ListItem
    @Binding var selection: Set<Conversation>
    @Binding var editingItem: ListItem?
    @Binding var newTitle: String
    @FocusState var fieldFocused: Bool
    @Binding var selectedFolder: Folder?
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack {
            if item.isFolder {
                Image(systemName: "folder")
            } else {
                Image(systemName: "doc.text")
            }
            itemContent
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !item.isFolder, let conversation = item.item as? Conversation {
                selection = [conversation]
            } else if item.isFolder, let folder = item.item as? Folder {
                selectedFolder = folder
            }
        }
        .contextMenu {
            Button("Rename") {
                startRenaming()
            }
            // Add other context menu items here
        }
    }

    @ViewBuilder
    private var itemContent: some View {
        if editingItem?.id == item.id {
            TextField("Name", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit(saveNewTitle)
                .onExitCommand { editingItem = nil }
        } else {
            Text(item.item.name ?? "Unnamed")
        }
    }

    private func startRenaming() {
        editingItem = item
        newTitle = item.item.name ?? ""
        fieldFocused = true
    }

    private func saveNewTitle() {
        DispatchQueue.main.async {
            do {
                if let conversation = item.item as? Conversation {
                    conversation.title = newTitle
                } else if let folder = item.item as? Folder {
                    folder.name = newTitle
                }
                try viewContext.save()
                editingItem = nil
            } catch {
                print("Error saving new title: \(error)")
            }
        }
    }
}

struct ListItem: Identifiable, Equatable {
    let id: String
    let item: HierarchicalItem
    var children: [ListItem]?
    
    var isFolder: Bool {
        return item is Folder
    }
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
        return lhs.id == rhs.id
    }
}

protocol HierarchicalItem: AnyObject {
    var name: String? { get }
}

extension Conversation: HierarchicalItem {
    var name: String? {
        return self.title ?? self.titleWithDefault
    }
}

#if DEBUG
struct NavList_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        return NavList(selection: .constant(Set()), showDeleteConfirmation: .constant(false))
            .environment(\.managedObjectContext, context)
    }
}
#endif
