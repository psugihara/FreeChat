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
    
    @State private var selectedItemId: String?
    @State private var lastSelectedChat: Conversation?
    @State private var refreshTrigger = UUID()

    var body: some View {
        
      List(hierarchicalItems, children: \.children) { item in
            
        HierarchicalItemRow(item: item,
                                selectedItemId: $selectedItemId,
                                lastSelectedChat: $lastSelectedChat,
                                editingItem: $editingItem,
                                newTitle: $newTitle,
                                fieldFocused: _fieldFocused,
                            refreshTrigger: $refreshTrigger)
        
        
        
        
        
        }
        //.frame(maxWidth: .infinity)
        //.listStyle(SidebarListStyle())
        .onChange(of: lastSelectedChat) { newValue in
            if let newChat = newValue {
                selection = [newChat]
            }
        }
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
        .onAppear(perform: refreshItems)
        .onChange(of: refreshTrigger) { _ in refreshItems() }
    }

    private func refreshItems() {
        DispatchQueue.main.async {
            do {
                let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
                folderFetchRequest.predicate = NSPredicate(format: "parent == nil")
                folderFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
                let rootFolders = try viewContext.fetch(folderFetchRequest)
                
                let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
                conversationFetchRequest.predicate = NSPredicate(format: "folder == nil")
                conversationFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: false)]
                let rootConversations = try viewContext.fetch(conversationFetchRequest)
                
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
        
        for conversation in conversations {
            let item = ListItem(id: conversation.objectID.uriRepresentation().absoluteString, item: conversation, children: nil)
            items.append(item)
        }
        
        return items
    }

    private func getSelectedFolder() -> Folder? {
        if let selectedId = selectedItemId,
           let selectedItem = hierarchicalItems.flatMap({ $0.allItems }).first(where: { $0.id == selectedId }),
           let folder = selectedItem.item as? Folder {
            return folder
        }
        return nil
    }

    private func newConversation() {
        do {
            let conversation = try Conversation.create(ctx: viewContext)
            conversation.folder = getSelectedFolder()
            try viewContext.save()
            refreshTrigger = UUID()
            lastSelectedChat = conversation
            selectedItemId = conversation.objectID.uriRepresentation().absoluteString
        } catch {
            print("Error creating new conversation: \(error)")
        }
    }

    private func createFolder() {
        let folderName = "New Folder"
        do {
            let newFolder = try Folder.create(ctx: viewContext, name: folderName, parent: getSelectedFolder())
            try viewContext.save()
            refreshTrigger = UUID()
            selectedItemId = newFolder.objectID.uriRepresentation().absoluteString
        } catch {
            print("An error occurred while creating the new folder: \(error)")
        }
    }
}

struct HierarchicalItemRow: View {
    let item: ListItem
    @Binding var selectedItemId: String?
    @Binding var lastSelectedChat: Conversation?
    @Binding var editingItem: ListItem?
    @Binding var newTitle: String
    @FocusState var fieldFocused: Bool
    @Binding var refreshTrigger: UUID
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack {
            if item.isFolder {
                Image(systemName: "folder")
            } else {
                Image(systemName: "doc.text")
            }
          
            itemContent
          
            Spacer()
        }
        .contentShape(Rectangle())
        .listRowBackground(selectedItemId == item.id ? Color.blue : Color.clear)
        .padding(.leading, item.isFolder ? 0 : 16) // Indent chats
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 8))
        .onTapGesture {
            selectedItemId = item.id
            if !item.isFolder, let conversation = item.item as? Conversation {
                lastSelectedChat = conversation
            }
        }
        .contextMenu {
            Button("Rename") {
                startRenaming()
            }
            if let conversation = item.item as? Conversation {
               Button("Delete") {
                   viewContext.delete(conversation)
                   do {
                       try viewContext.save()
                       refreshTrigger = UUID()  // Trigger a refresh after deletion
                   } catch {
                       print("Error deleting conversation: \(error)")
                   }
               }
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

extension ListItem {
    var allItems: [ListItem] {
        var items = [self]
        if let children = self.children {
            items.append(contentsOf: children.flatMap { $0.allItems })
        }
        return items
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
