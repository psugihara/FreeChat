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
    @StateObject private var hierarchyManager: ConversationHierarchyManager
    
    @Binding var selection: Set<Conversation>
    @Binding var showDeleteConfirmation: Bool
    
    @State private var editingItem: NavItem?
    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool
    
    @State private var selectedItemId: String?
    @State private var lastSelectedChat: Conversation?
    
    @State private var showingDeleteFolderConfirmation = false
    @State private var folderToDelete: Folder?
    
    @State private var draggedItem: NavItem?
    @State private var dropTargetID: String?

    init(selection: Binding<Set<Conversation>>, showDeleteConfirmation: Binding<Bool>, viewContext: NSManagedObjectContext) {
        self._selection = selection
        self._showDeleteConfirmation = showDeleteConfirmation
        self._hierarchyManager = StateObject(wrappedValue: ConversationHierarchyManager(viewContext: viewContext))
    }

    var body: some View {
        List(hierarchyManager.navItems, children: \.children) { item in
            NavItemRow(item: item,
                       selectedItemId: $selectedItemId,
                       lastSelectedChat: $lastSelectedChat,
                       editingItem: $editingItem,
                       newTitle: $newTitle,
                       fieldFocused: _fieldFocused,
                       showingDeleteFolderConfirmation: $showingDeleteFolderConfirmation,
                       folderToDelete: $folderToDelete,
                       viewContext: viewContext,
                       draggedItem: $draggedItem,
                       dropTargetID: $dropTargetID,
                       hierarchyManager: hierarchyManager)
                .onDrag {
                    self.draggedItem = item
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(of: [.text], delegate: NavItemDropDelegate(item: item,
                                                                   viewContext: viewContext,
                                                                   hierarchyManager: hierarchyManager,
                                                                   draggedItem: $draggedItem,
                                                                   dropTargetID: $dropTargetID))
        }
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
        .alert("Delete Folder", isPresented: $showingDeleteFolderConfirmation, presenting: folderToDelete) { folder in
            Button("Yes", role: .destructive) {
                deleteFolder(folder)
            }
            Button("No", role: .cancel) {}
        } message: { folder in
            Text("Are you sure you want to delete the folder \(folder.name ?? "Unnamed") and all of its contents?")
        }
    }

  private func newConversation() {
          do {
              let conversation = try Conversation.create(ctx: viewContext)
              conversation.folder = getSelectedFolder()
              try viewContext.save()
              hierarchyManager.refreshHierarchy()
              lastSelectedChat = conversation
              selectedItemId = NavItem.conversation(conversation).id
          } catch {
              print("Error creating new conversation: \(error)")
          }
      }

      private func createFolder() {
          let folderName = "New Folder"
          do {
              let newFolder = try Folder.create(ctx: viewContext, name: folderName, parent: getSelectedFolder())
              try viewContext.save()
              hierarchyManager.refreshHierarchy()
              selectedItemId = NavItem.folder(FolderNode(folder: newFolder, subfolders: [], conversations: [])).id
          } catch {
              print("An error occurred while creating the new folder: \(error)")
          }
      }
      
      private func deleteFolder(_ folder: Folder) {
          do {
              try Folder.deleteFolder(folder, in: viewContext)
              try viewContext.save()
              hierarchyManager.refreshHierarchy()
          } catch {
              print("Error deleting folder: \(error)")
          }
      }

      private func getSelectedFolder() -> Folder? {
          if let selectedId = selectedItemId,
             case .folder(let folderNode) = hierarchyManager.navItems.first(where: { $0.id == selectedId }) {
              return folderNode.folder
          }
          return nil
      }
  
 
}

struct NavItemRow: View {
    let item: NavItem
    @Binding var selectedItemId: String?
    @Binding var lastSelectedChat: Conversation?
    @Binding var editingItem: NavItem?
    @Binding var newTitle: String
    @FocusState var fieldFocused: Bool
    @Binding var showingDeleteFolderConfirmation: Bool
    @Binding var folderToDelete: Folder?
    let viewContext: NSManagedObjectContext
    @Binding var draggedItem: NavItem?
    @Binding var dropTargetID: String?
    let hierarchyManager: ConversationHierarchyManager

    @State private var showContextMenu = false

    var body: some View {
        HStack {
            if case .folder = item {
                Image(systemName: "folder")
            } else {
                Image(systemName: "doc.text")
            }
            
            itemContent
            
            Spacer()

            if dropTargetID == item.id, case .folder = item {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .contentShape(Rectangle())
        .listRowBackground(selectedItemId == item.id ? Color.blue.opacity(0.3) : Color.clear)
        .padding(.leading, item.isFolder ? 0 : 16)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 8))
        .onTapGesture {
            selectedItemId = item.id
            if case .conversation(let conversation) = item {
                lastSelectedChat = conversation
            }
        }
        .onHover { hovering in
            showContextMenu = hovering
        }
        .contextMenu {
            Button("Rename") {
                startRenaming()
            }
            
            if case .conversation(let conversation) = item {
                Button("Delete", role: .destructive) {
                    deleteConversation(conversation)
                }
            } else if case .folder(let folderNode) = item {
                Button("Delete Folder and Contents", role: .destructive) {
                    folderToDelete = folderNode.folder
                    showingDeleteFolderConfirmation = true
                }
            }
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
            Text(item.name)
        }
    }

    private func startRenaming() {
        editingItem = item
        newTitle = item.name
        fieldFocused = true
    }

    private func saveNewTitle() {
        do {
            switch item {
            case .conversation(let conversation):
                conversation.title = newTitle
            case .folder(let folderNode):
                folderNode.folder.name = newTitle
            }
            try viewContext.save()
            editingItem = nil
            hierarchyManager.refreshHierarchy()
        } catch {
            print("Error saving new title: \(error)")
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        viewContext.delete(conversation)
        do {
            try viewContext.save()
            hierarchyManager.refreshHierarchy()
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }
}

struct NavItemDropDelegate: DropDelegate {
    let item: NavItem
    let viewContext: NSManagedObjectContext
    let hierarchyManager: ConversationHierarchyManager
    @Binding var draggedItem: NavItem?
    @Binding var dropTargetID: String?

    func performDrop(info: DropInfo) -> Bool {
        guard let sourceItem = draggedItem else { return false }
        
        switch (sourceItem, item) {
        case (.conversation(let conversation), .folder(let destinationFolder)):
            conversation.folder = destinationFolder.folder
        case (.folder(let sourceFolder), .folder(let destinationFolder)):
            sourceFolder.folder.parent = destinationFolder.folder
        case (.conversation(let conversation), .conversation):
            // Move to root if dropped on another conversation
            conversation.folder = nil
        case (.folder(let folder), .conversation):
            // Move to root if dropped on a conversation
            folder.folder.parent = nil
        }
        
        do {
            try viewContext.save()
            hierarchyManager.refreshHierarchy()
        } catch {
            print("Error saving after drop: \(error)")
        }
        
        draggedItem = nil
        dropTargetID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        self.dropTargetID = item.id
    }

    func dropExited(info: DropInfo) {
        self.dropTargetID = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

class ConversationHierarchyManager: ObservableObject {
    @Published var navItems: [NavItem] = []
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        refreshHierarchy()
    }
    
    func refreshHierarchy() {
        let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        folderFetchRequest.predicate = NSPredicate(format: "parent == nil")
        folderFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.orderIndex, ascending: true)]
        
        let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        conversationFetchRequest.predicate = NSPredicate(format: "folder == nil")
        conversationFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.orderIndex, ascending: true)]
        
        do {
            let rootFolders = try viewContext.fetch(folderFetchRequest)
            let rootConversations = try viewContext.fetch(conversationFetchRequest)
            
            navItems = rootFolders.map { NavItem.folder(createFolderNode(from: $0)) } +
                       rootConversations.map { NavItem.conversation($0) }
        } catch {
            print("Failed to fetch root items: \(error)")
        }
    }
    
    private func createFolderNode(from folder: Folder) -> FolderNode {
        let subfolderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        subfolderFetchRequest.predicate = NSPredicate(format: "parent == %@", folder)
        subfolderFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.orderIndex, ascending: true)]
        
        let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        conversationFetchRequest.predicate = NSPredicate(format: "folder == %@", folder)
        conversationFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.orderIndex, ascending: true)]
        
        do {
            let subfolders = try viewContext.fetch(subfolderFetchRequest)
            let conversations = try viewContext.fetch(conversationFetchRequest)
            
            return FolderNode(
                folder: folder,
                subfolders: subfolders.map { createFolderNode(from: $0) },
                conversations: conversations
            )
        } catch {
            print("Failed to fetch items for folder \(folder.name ?? ""): \(error)")
            return FolderNode(folder: folder, subfolders: [], conversations: [])
        }
    }
}

extension NavItem {
    var children: [NavItem]? {
        switch self {
        case .folder(let folderNode):
            return folderNode.subfolders.map { NavItem.folder($0) } +
                   folderNode.conversations.map { NavItem.conversation($0) }
        case .conversation:
            return nil
        }
    }
    
    var name: String {
        switch self {
        case .folder(let folderNode):
            return folderNode.folder.name ?? "Unnamed Folder"
        case .conversation(let conversation):
            return conversation.title ?? conversation.titleWithDefault
        }
    }
    
    var isFolder: Bool {
        if case .folder = self {
            return true
        }
        return false
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
    @Binding var showingDeleteFolderConfirmation: Bool
    @Binding var folderToDelete: Folder?
    let viewContext: NSManagedObjectContext

    @State private var showContextMenu = false
  @Binding var draggedItem: ListItem?
      @Binding var dropTargetID: String?

  var body: some View {
          HStack {
              if item.isFolder {
                  Image(systemName: "folder")
              } else {
                  Image(systemName: "doc.text")
              }
              
              itemContent
              
              Spacer()

              if dropTargetID == item.id && item.isFolder {
                  Image(systemName: "plus.circle.fill")
                      .foregroundColor(.green)
              }
          }
          .contentShape(Rectangle())
          .listRowBackground(selectedItemId == item.id ? Color.blue.opacity(0.3) : Color.clear)
          .padding(.leading, item.isFolder ? 0 : 16)
          .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 8))
          .onTapGesture {
              selectedItemId = item.id
              if !item.isFolder, let conversation = item.item as? Conversation {
                  lastSelectedChat = conversation
              }
          }
        .onHover { hovering in
            showContextMenu = hovering
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
                refreshTrigger = UUID()
            } catch {
                print("Error saving new title: \(error)")
            }
        }
    }

  private func deleteConversation(_ conversation: Conversation) {
          viewContext.delete(conversation)
          do {
              try viewContext.save()
              refreshTrigger = UUID()
          } catch {
              print("Error deleting conversation: \(error)")
          }
      }
}

struct ItemDropDelegate: DropDelegate {
    let item: ListItem
    @Binding var items: [ListItem]
    let viewContext: NSManagedObjectContext
    @Binding var refreshTrigger: UUID
    @Binding var draggedItem: ListItem?
    @Binding var dropTargetID: String?

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSString.self) { (id, error) in
            if let id = id as? String,
               let sourceItem = self.draggedItem,
               let destinationFolder = self.item.item as? Folder {
                DispatchQueue.main.async {
                    if let conversation = sourceItem.item as? Conversation {
                        conversation.folder = destinationFolder
                    } else if let folder = sourceItem.item as? Folder {
                        folder.parent = destinationFolder
                    }
                    do {
                        try self.viewContext.save()
                        self.refreshTrigger = UUID()
                    } catch {
                        print("Error saving after drop: \(error)")
                    }
                    self.draggedItem = nil
                    self.dropTargetID = nil
                }
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        self.dropTargetID = item.id
    }

    func dropExited(info: DropInfo) {
        self.dropTargetID = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
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

extension Folder {
    static func deleteFolder(_ folder: Folder, in context: NSManagedObjectContext) throws {
        // Delete all conversations in this folder
        if let conversations = folder.conversation as? Set<Conversation> {
            for conversation in conversations {
                context.delete(conversation)
            }
        }
        
        // Recursively delete subfolders
        if let subfolders = folder.subfolders as? Set<Folder> {
            for subfolder in subfolders {
                try deleteFolder(subfolder, in: context)
              
              // Delete all conversations in this folder
              if let conversations = folder.conversation as? Set<Conversation> {
                  for conversation in conversations {
                      context.delete(conversation)
                  }
              }
            }
        }
        
        // Delete the folder itself
        context.delete(folder)
    }
}

/*#if DEBUG
struct NavList_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        return NavList(selection: .constant(Set()), showDeleteConfirmation: .constant(false))
            .environment(\.managedObjectContext, context)
    }
}
#endif*/
