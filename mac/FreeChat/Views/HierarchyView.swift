import SwiftUI
import CoreData

struct HierarchyView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @StateObject private var hierarchyManager: ConversationHierarchyManager
  
  @Binding var selection: Set<Conversation>
  @Binding var showDeleteConfirmation: Bool
  
  @State private var editingItem: HierarchyItem?
  @State private var newTitle = ""
  @FocusState private var fieldFocused: Bool
  
  @State private var selectedItemId: NSManagedObjectID?
  @State private var lastSelectedChat: Conversation?
  
  @State private var showingDeleteFolderConfirmation = false
  @State private var folderToDelete: Folder?
  
  @State private var draggedItem: HierarchyItem?
  @State private var dropTargetID: NSManagedObjectID?
  
  @State private var selectedContextMenuItem: HierarchyItem?
  
  @State private var contextMenuSelectedItem: HierarchyItem?
  
  @EnvironmentObject var conversationManager: ConversationManager
  
  
  
  init(selection: Binding<Set<Conversation>>, showDeleteConfirmation: Binding<Bool>, viewContext: NSManagedObjectContext) {
    self._selection = selection
    self._showDeleteConfirmation = showDeleteConfirmation
    self._hierarchyManager = StateObject(wrappedValue: ConversationHierarchyManager(viewContext: viewContext))
  }
  
  var body: some View {
    List(hierarchyManager.hierarchyItems, children: \.children) { item in
      HierarchyItemRow(item: item,
                       selectedItemId: $selectedItemId,
                       folderToDelete: $folderToDelete,
                       showingDeleteFolderConfirmation: $showingDeleteFolderConfirmation,
                       draggedItem: $draggedItem,
                       dropTargetID: $dropTargetID,
                       editingItem: $editingItem,  // Add this
                       newTitle: $newTitle,  // Add this
                       viewContext: viewContext,
                       hierarchyManager: hierarchyManager)
        .listRowInsets(EdgeInsets())
        .contentShape(Rectangle())
        //.contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            selectedItemId = item.id
        }
        .contextMenu {
            Button(action: {
                contextMenuSelectedItem = item
                renameItem()
            }) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: {
                contextMenuSelectedItem = item
                deleteItem()
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        
        .listRowBackground(
                           RoundedRectangle(cornerRadius: 8).fill(rowBackgroundColor(for: item))
                            .padding(.horizontal, 8)
        )
      
    }
    .onChange(of: draggedItem) { _ in
      if draggedItem == nil {
        hierarchyManager.updateItemOrder()
      }
    }
    .onChange(of: selectedItemId) { newValue in
      if let id = newValue,
         let conversation = hierarchyManager.findConversation(withId: id) {
        selection = [conversation]
        conversationManager.currentConversation = conversation
      } else {
        selection = []
        conversationManager.unsetConversation()
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
  
  private func rowBackgroundColor(for item: HierarchyItem) -> Color {
      selectedItemId == item.id ? Color(NSColor.selectedControlColor) : Color.clear
  }
  
  private func startRenaming(_ item: HierarchyItem) {
      print("startRenaming called for item: \(item.name)")
      editingItem = item
      newTitle = item.name
      print("editingItem set to: \(editingItem?.name ?? "nil")")
      print("newTitle set to: \(newTitle)")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          print("Setting fieldFocused to true")
          fieldFocused = true
      }
  }
  
  private func testingThisWorks(){
    print("testing this works")
  }
  
  private func renameItem() {
      print("Rename function called")
      print("Context menu selected item: \(contextMenuSelectedItem?.name ?? "nil")")
      guard let item = contextMenuSelectedItem else {
          print("No item selected for renaming")
          return
      }
      print("Calling startRenaming for item: \(item.name)")
      startRenaming(item)
  }

  private func deleteItem() {
      print("Context menu selected item: \(contextMenuSelectedItem?.name ?? "nil")")
      guard let item = contextMenuSelectedItem else {
          print("No item selected for deletion")
          return
      }
      if item.isFolder {
          folderToDelete = item.folder
          showingDeleteFolderConfirmation = true
      } else {
          if let conversation = item.conversation {
              deleteConversation(conversation)
          }
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
      selection = [conversation]
      selectedItemId = conversation.objectID
    } catch {
      print("Error creating new conversation: \(error)")
    }
  }
  
  private func createFolder() {
    let folderName = "New Folder"
    do {
      let newFolder = try Folder.create(ctx: viewContext, name: folderName, parent: hierarchyManager.findFolder(withId: selectedItemId))
      try viewContext.save()
      hierarchyManager.refreshHierarchy()
      selectedItemId = newFolder.objectID
    } catch {
      print("An error occurred while creating the new folder: \(error)")
    }
  }
  
  private func deleteFolder(_ folder: Folder) {
    do {
      try deleteFolder(folder, in: viewContext)
      try viewContext.save()
      hierarchyManager.refreshHierarchy()
    } catch {
      print("Error deleting folder: \(error)")
    }
  }
  
  private func deleteFolder(_ folder: Folder, in context: NSManagedObjectContext) throws {
    // Recursively delete subfolders
    for subfolder in folder.subfolders ?? [] {
      try deleteFolder(subfolder, in: context)
    }
    
    // Delete all conversations in this folder
    if let conversations = folder.conversation as? Set<Conversation> {
      for conversation in conversations {
        context.delete(conversation)
      }
    }
    
    // Delete the folder itself
    context.delete(folder)
  }
  
  private func saveNewTitle() {
    guard let item = editingItem else { return }
    hierarchyManager.renameItem(item, newName: newTitle)
    editingItem = nil
    fieldFocused = false
    hierarchyManager.refreshHierarchy() // Refresh to show the updated name
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

struct HierarchyItemRow: View {
    var item: HierarchyItem
    @Binding var selectedItemId: NSManagedObjectID?
    @Binding var folderToDelete: Folder?
    @Binding var showingDeleteFolderConfirmation: Bool
    @Binding var draggedItem: HierarchyItem?
    @Binding var dropTargetID: NSManagedObjectID?
    @Binding var editingItem: HierarchyItem?  // Add this
    @Binding var newTitle: String  // Add this
    var viewContext: NSManagedObjectContext
    var hierarchyManager: ConversationHierarchyManager
    
    @FocusState private var fieldFocused: Bool
  
  var body: some View {
    HStack {
      if item.isFolder {
        Text(item.isOpen ? "📂" : "📁")
      } else {
        Text("📄")
      }
      
      if editingItem?.id == item.id {
                  TextField("", text: $newTitle, onCommit: saveNewTitle)
                      .textFieldStyle(RoundedBorderTextFieldStyle())
                      .focused($fieldFocused)
                      .onSubmit {
                          saveNewTitle()
                      }
              } else {
                  Text(item.name)
              }
      
      Spacer()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 6)
    //.frame(maxWidth: .infinity, alignment: .leading)
    //.background(
    //  RoundedRectangle(cornerRadius: 8)
    //    .fill(selectedItemId == item.id ? Color(NSColor.selectedControlColor) : Color.clear)
    //)
    .contentShape(Rectangle()) // This makes the whole row clickable (above and below the text) - otherwise the tap target is too small
    .onTapGesture {
      selectedItemId = item.id
    }
    
    .onDrag {
      self.draggedItem = item
      return NSItemProvider(object: item.id.uriRepresentation().absoluteString as NSString)
    }
    .onDrop(of: [.text], delegate: HierarchyItemDropDelegate(item: item,
                                                             viewContext: viewContext,
                                                             hierarchyManager: hierarchyManager,
                                                             draggedItem: $draggedItem,
                                                             dropTargetID: $dropTargetID))
  }
  
  private func startRenaming(_ item: HierarchyItem) {
    editingItem = item
    newTitle = item.name
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      fieldFocused = true
    }
  }
  
  private func saveNewTitle() {
      print("saveNewTitle called")
      guard let item = editingItem else {
          print("No item being edited")
          return
      }
      print("Saving new title: \(newTitle) for item: \(item.name)")
      hierarchyManager.renameItem(item, newName: newTitle)
      editingItem = nil
      fieldFocused = false
      print("editingItem set to nil, fieldFocused set to false")
      hierarchyManager.refreshHierarchy()
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

class HierarchyItem: Identifiable, Hashable {
  let id: NSManagedObjectID
  var name: String
  var children: [HierarchyItem]?
  var isFolder: Bool
  var folder: Folder?
  var conversation: Conversation?
  var isOpen: Bool
  
  init(id: NSManagedObjectID, name: String, children: [HierarchyItem]? = nil, isFolder: Bool, folder: Folder? = nil, conversation: Conversation? = nil, isOpen: Bool) {
    self.id = id
    self.name = name
    self.children = children
    self.isFolder = isFolder
    self.folder = folder
    self.conversation = conversation
    self.isOpen = isOpen
  }
  
  static func == (lhs: HierarchyItem, rhs: HierarchyItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

class ConversationHierarchyManager: ObservableObject {
  @Published var hierarchyItems: [HierarchyItem] = []
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
      
      hierarchyItems = rootFolders.map { createHierarchyItem(from: $0) } +
      rootConversations.map { createHierarchyItem(from: $0) }
    } catch {
      print("Failed to fetch root items: \(error)")
    }
  }
  
  private func createHierarchyItem(from folder: Folder) -> HierarchyItem {
    let subfolderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
    subfolderFetchRequest.predicate = NSPredicate(format: "parent == %@", folder)
    subfolderFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.orderIndex, ascending: true)]
    
    let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
    conversationFetchRequest.predicate = NSPredicate(format: "folder == %@", folder)
    conversationFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.orderIndex, ascending: true)]
    
    do {
      let subfolders = try viewContext.fetch(subfolderFetchRequest)
      let conversations = try viewContext.fetch(conversationFetchRequest)
      
      let children = subfolders.map { createHierarchyItem(from: $0) } +
      conversations.map { createHierarchyItem(from: $0) }
      
      return HierarchyItem(id: folder.objectID, name: folder.name ?? "Unnamed Folder", children: children, isFolder: true, folder: folder, isOpen: folder.open)
    } catch {
      print("Failed to fetch items for folder \(folder.name ?? ""): \(error)")
      return HierarchyItem(id: folder.objectID, name: folder.name ?? "Unnamed Folder", children: [], isFolder: true, folder: folder, isOpen: folder.open)
    }
  }
  
  private func createHierarchyItem(from conversation: Conversation) -> HierarchyItem {
    HierarchyItem(id: conversation.objectID, name: conversation.title ?? conversation.titleWithDefault, isFolder: false, conversation: conversation, isOpen: false)
  }
  
  func toggleFolderOpen(_ item: HierarchyItem) {
    guard let folder = item.folder else { return }
    folder.open.toggle()
    try? viewContext.save()
    refreshHierarchy()
  }
  
  func updateItemOrder() {
    updateOrder(items: hierarchyItems)
    try? viewContext.save()
  }
  
  private func updateOrder(items: [HierarchyItem], parentFolder: Folder? = nil) {
    for (index, item) in items.enumerated() {
      if item.isFolder {
        item.folder?.orderIndex = Int32(index)
        item.folder?.parent = parentFolder
        if let children = item.children {
          updateOrder(items: children, parentFolder: item.folder)
        }
      } else {
        item.conversation?.orderIndex = Int32(index)
        item.conversation?.folder = parentFolder
      }
    }
  }
  
  func renameItem(_ item: HierarchyItem, newName: String) {
    if item.isFolder {
      item.folder?.name = newName
    } else {
      item.conversation?.title = newName
    }
    
    do {
      try viewContext.save()
      refreshHierarchy()
    } catch {
      print("Error saving new name: \(error)")
    }
  }
  
  func findFolder(withId id: NSManagedObjectID?) -> Folder? {
    guard let id = id else { return nil }
    return findFolder(in: hierarchyItems, withId: id)
  }
  
  private func findFolder(in items: [HierarchyItem], withId id: NSManagedObjectID) -> Folder? {
    for item in items {
      if item.isFolder && item.id == id {
        return item.folder
      }
      if let children = item.children,
         let found = findFolder(in: children, withId: id) {
        return found
      }
    }
    return nil
  }
  
  func findConversation(withId id: NSManagedObjectID?) -> Conversation? {
    guard let id = id else { return nil }
    return findConversation(in: hierarchyItems, withId: id)
  }
  
  private func findConversation(in items: [HierarchyItem], withId id: NSManagedObjectID) -> Conversation? {
    for item in items {
      if !item.isFolder && item.id == id {
        return item.conversation
      }
      if let children = item.children,
         let found = findConversation(in: children, withId: id) {
        return found
      }
    }
    return nil
  }
}

struct HierarchyItemDropDelegate: DropDelegate {
  let item: HierarchyItem
  let viewContext: NSManagedObjectContext
  let hierarchyManager: ConversationHierarchyManager
  @Binding var draggedItem: HierarchyItem?
  @Binding var dropTargetID: NSManagedObjectID?
  
  func performDrop(info: DropInfo) -> Bool {
    guard let sourceItem = draggedItem else { return false }
    
    if sourceItem.isFolder {
      if let sourceFolder = sourceItem.folder,
         let destinationFolder = item.isFolder ? item.folder : item.conversation?.folder {
        sourceFolder.parent = destinationFolder
      } else if !item.isFolder {
        sourceItem.folder?.parent = nil
      }
    } else {
      if item.isFolder {
        sourceItem.conversation?.folder = item.folder
      } else {
        sourceItem.conversation?.folder = item.conversation?.folder
      }
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
