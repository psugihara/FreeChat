import Foundation
import CoreData

class ConversationHierarchy {
    private let viewContext: NSManagedObjectContext
    
  @Published var folderHierarchy: [FolderNode] = []
      @Published var rootConversations: [Conversation] = []
  
  
  init(viewContext: NSManagedObjectContext) {
          self.viewContext = viewContext
          refreshHierarchy()
      }
      
      func refreshHierarchy() {
          (folderHierarchy, rootConversations) = getHierarchy()
      }
    
  func getHierarchy() -> ([FolderNode], [Conversation]) {
      do {
          let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
          folderFetchRequest.predicate = NSPredicate(format: "parent == nil")
          let rootFolders = try viewContext.fetch(folderFetchRequest)
          
          let folderNodes = rootFolders
              .map { createFolderNode(from: $0) }
              .sorted { $0.folder.name?.lowercased() ?? "" < $1.folder.name?.lowercased() ?? "" }
          
          let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
          conversationFetchRequest.predicate = NSPredicate(format: "folder == nil")
          let rootConversations = try viewContext.fetch(conversationFetchRequest)
              .sorted { $0.titleWithDefault.lowercased() < $1.titleWithDefault.lowercased() }
          
          // Combine and sort folders and root conversations
          let combinedItems = (folderNodes as [Any] + rootConversations as [Any]).sorted {
              let title1 = ($0 as? FolderNode)?.folder.name?.lowercased() ?? ($0 as? Conversation)?.titleWithDefault.lowercased() ?? ""
              let title2 = ($1 as? FolderNode)?.folder.name?.lowercased() ?? ($1 as? Conversation)?.titleWithDefault.lowercased() ?? ""
              return title1 < title2
          }
          
          // Separate sorted items back into folders and conversations
          let sortedFolderNodes = combinedItems.compactMap { $0 as? FolderNode }
          let sortedRootConversations = combinedItems.compactMap { $0 as? Conversation }
          
          return (sortedFolderNodes, sortedRootConversations)
      } catch {
          print("Failed to fetch root items: \(error)")
          return ([], [])
      }
  }
    
  private func createFolderNode(from folder: Folder) -> FolderNode {
      let subfolders = folder.subfolders.map { createFolderNode(from: $0) }
      let conversations = fetchConversations(for: folder)
      
      // Combine and sort subfolders and conversations
      let combinedItems = (subfolders as [Any] + conversations as [Any]).sorted {
          let title1 = ($0 as? FolderNode)?.folder.name?.lowercased() ?? ($0 as? Conversation)?.titleWithDefault.lowercased() ?? ""
          let title2 = ($1 as? FolderNode)?.folder.name?.lowercased() ?? ($1 as? Conversation)?.titleWithDefault.lowercased() ?? ""
          return title1 < title2
      }
      
      // Separate sorted items back into subfolders and conversations
      let sortedSubfolders = combinedItems.compactMap { $0 as? FolderNode }
      let sortedConversations = combinedItems.compactMap { $0 as? Conversation }
      
      return FolderNode(folder: folder, subfolders: sortedSubfolders, conversations: sortedConversations)
  }
    
    private func fetchConversations(for folder: Folder) -> [Conversation] {
        let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "folder == %@", folder)
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch conversations for folder \(folder.name ?? ""): \(error)")
            return []
        }
    }
  
  private func sortFolderNodesAlphabetically(_ nodes: [FolderNode]) -> [FolderNode] {
      return nodes.sorted { $0.folder.name?.lowercased() ?? "" < $1.folder.name?.lowercased() ?? "" }.map { node in
          var sortedNode = node
          sortedNode.subfolders = sortFolderNodesAlphabetically(node.subfolders)
          sortedNode.conversations = node.conversations.sorted { $0.titleWithDefault.lowercased() < $1.titleWithDefault.lowercased() }
          return sortedNode
      }
  }
}


