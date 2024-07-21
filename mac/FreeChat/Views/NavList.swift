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
  
  @State private var contextMenuItem: NavItem?
  
  
  //@State private var contextMenuItemId: String?

    init(selection: Binding<Set<Conversation>>, showDeleteConfirmation: Binding<Bool>, viewContext: NSManagedObjectContext) {
        self._selection = selection
        self._showDeleteConfirmation = showDeleteConfirmation
        self._hierarchyManager = StateObject(wrappedValue: ConversationHierarchyManager(viewContext: viewContext))
    }

  var body: some View {
    List {
                ForEach(hierarchyManager.navItems) { item in
                    NavItemContent(item: item)
                        /*.contextMenu {
                            Button("Rename") {
                                  contextMenuItem = item
                                  startRenaming(item)
                              
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
                        }*/
                }
            }
        .onChange(of: lastSelectedChat) { newValue in
            if let newChat = newValue {
                selection = [newChat]
            }
        }
        .onChange(of: draggedItem) { _ in
            if draggedItem == nil {
                hierarchyManager.updateItemOrder()
            }
        }
        .onAppear {
            hierarchyManager.refreshHierarchy()
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
          if let selectedId = selectedItemId,
             let folder = hierarchyManager.findFolder(withId: selectedId) {
              conversation.folder = folder
          }
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
            selectedItemId = NavItem.folder(FolderNode(folder: newFolder,subfolders: [], conversations: [], isOpen: false)).id
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
  
  private func startRenaming(_ item: NavItem) {
    print(item.name)
    //print(item.children)
    editingItem = item
      contextMenuItem = item
      newTitle = item.name
      fieldFocused = true
  }
  
  private func saveNewTitle() {
    print("saveNewTile triggered")
    guard let item = editingItem ?? contextMenuItem else { return }
      hierarchyManager.renameItem(item, newName: newTitle)
      editingItem = nil
      contextMenuItem = nil  // Add this line
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
  
  
  
  @ViewBuilder
  func NavItemContent(item: NavItem) -> some View {
      switch item {
      case .folder(let folderNode):
          FolderContent(folderNode: folderNode,
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
                        hierarchyManager: hierarchyManager,
                        saveNewTitle: saveNewTitle,
                        contextMenuItem: $contextMenuItem)
          
      case .conversation(let conversation):
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
                     hierarchyManager: hierarchyManager,
                     contextMenuItem: $contextMenuItem,
                     saveNewTitle: saveNewTitle
                     )
      }
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
  @ObservedObject var hierarchyManager: ConversationHierarchyManager
  @Binding var contextMenuItem: NavItem?
  
  @State private var isOpen: Bool = false
  let saveNewTitle: () -> Void
  
  var body: some View {
    HStack {
      
      
      
      if case .folder(let folderNode) = item {
        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                withAnimation {
                                    isOpen.toggle()
                                    hierarchyManager.toggleFolderOpen(folderNode)
                                }
                            }
        Image(systemName: "folder")
          .foregroundColor(.blue)
      } else {
        Image(systemName: "doc.text")
          .foregroundColor(.gray)
      }
      
      if editingItem?.id == item.id || contextMenuItem?.id == item.id {
          TextField("Name", text: $newTitle)
              .textFieldStyle(PlainTextFieldStyle())
              .focused($fieldFocused)
              .onSubmit {
                  saveNewTitle()
                  editingItem = nil
                  contextMenuItem = nil
              }
              .onExitCommand {
                  editingItem = nil
                  contextMenuItem = nil
              }
      } else {
          Text(item.name)
      }
        
        Spacer()
        
        if dropTargetID == item.id, case .folder = item {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(.green)
        }
      }
      //.contentShape(Rectangle())
        .listRowBackground(selectedItemId == item.id ? Color.blue.opacity(0.3) : Color.clear)
        .onTapGesture {
          selectedItemId = item.id
          if case .conversation(let conversation) = item {
            lastSelectedChat = conversation
          }
        }
        .onDrag {
          self.draggedItem = self.item
          return NSItemProvider(object: self.item.id as NSString)
        }
        .onDrop(of: [.text], delegate: NavItemDropDelegate(item: item,
                                                           viewContext: viewContext,
                                                           hierarchyManager: hierarchyManager,
                                                           draggedItem: $draggedItem,
                                                           dropTargetID: $dropTargetID))
        .onAppear {
          if case .folder(let folderNode) = item {
            isOpen = folderNode.folder.open
          }
        }
    
        .contextMenu {
                    Button(action: {
                        contextMenuItem = item
                        startRenamingItem()
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    if case .conversation(let conversation) = item {
                        Button(action: {
                            deleteConversation(conversation)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } else if case .folder(let folderNode) = item {
                        Button(action: {
                            folderToDelete = folderNode.folder
                            showingDeleteFolderConfirmation = true
                        }) {
                            Label("Delete Folder and Contents", systemImage: "trash")
                        }
                    }
                }
    }
    
     private func updateFolderOpenState() {
      if case .folder(let folderNode) = item {
        folderNode.folder.open = isOpen
        try? viewContext.save()
        hierarchyManager.refreshHierarchy()
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
  
  private func startRenamingItem(){
    print(item)
    
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
                conversations: conversations,
                isOpen: folder.open
            )
        } catch {
            print("Failed to fetch items for folder \(folder.name ?? ""): \(error)")
            return FolderNode(folder: folder, subfolders: [], conversations: [], isOpen: folder.open)
        }
    }
    
    func toggleFolderOpen(_ folderNode: FolderNode) {
        folderNode.folder.open.toggle()
        try? viewContext.save()
        refreshHierarchy()
    }
    
    func updateItemOrder() {
        updateOrder(items: navItems)
        try? viewContext.save()
    }
    
    private func updateOrder(items: [NavItem], parentFolder: Folder? = nil) {
        for (index, item) in items.enumerated() {
            switch item {
            case .folder(let folderNode):
                folderNode.folder.orderIndex = Int32(index)
                folderNode.folder.parent = parentFolder
                updateOrder(items: folderNode.subfolders.map { NavItem.folder($0) } + folderNode.conversations.map { NavItem.conversation($0) }, parentFolder: folderNode.folder)
            case .conversation(let conversation):
                conversation.orderIndex = Int32(index)
                conversation.folder = parentFolder
            }
        }
    }
  
  func renameItem(_ item: NavItem, newName: String) {
      switch item {
      case .conversation(let conversation):
          conversation.title = newName
      case .folder(let folderNode):
          folderNode.folder.name = newName
      }
      
      do {
          try viewContext.save()
          refreshHierarchy()
      } catch {
          print("Error saving new name: \(error)")
      }
  }
  
  func findFolder(withId id: String) -> Folder? {
      func search(in items: [NavItem]) -> Folder? {
          for item in items {
              if case .folder(let folderNode) = item, "\(folderNode.folder.id)" == id {
                  return folderNode.folder
              }
              if let children = item.children, let found = search(in: children) {
                  return found
              }
          }
          return nil
      }
      return search(in: navItems)
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




struct FolderContent: View {
    let folderNode: FolderNode
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
    @ObservedObject var hierarchyManager: ConversationHierarchyManager
      let saveNewTitle: () -> Void
  @Binding var contextMenuItem: NavItem?
  
  
  var body: some View {
      
          NavItemRow(item: .folder(folderNode),
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
                     hierarchyManager: hierarchyManager,
                     contextMenuItem: $contextMenuItem,
                     saveNewTitle: saveNewTitle)

          if folderNode.isOpen {
              ForEach(folderNode.subfolders) { subfolder in
                  FolderContent(folderNode: subfolder,
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
                                hierarchyManager: hierarchyManager,
                                saveNewTitle: saveNewTitle,
                                contextMenuItem: $contextMenuItem)
                      .padding(.leading, 20)
              }
              ForEach(folderNode.conversations) { conversation in
                  NavItemRow(item: .conversation(conversation),
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
                             hierarchyManager: hierarchyManager,
                             contextMenuItem: $contextMenuItem,
                             saveNewTitle: saveNewTitle)
                      .padding(.leading, 20)
              }
          }
      }
}
