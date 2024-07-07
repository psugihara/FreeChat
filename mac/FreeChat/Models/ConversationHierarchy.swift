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
            
            let folderNodes = rootFolders.map { createFolderNode(from: $0) }
            
            let conversationFetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            conversationFetchRequest.predicate = NSPredicate(format: "folder == nil")
            let rootConversations = try viewContext.fetch(conversationFetchRequest)
            
            return (folderNodes, rootConversations)
        } catch {
            print("Failed to fetch root items: \(error)")
            return ([], [])
        }
    }
    
    private func createFolderNode(from folder: Folder) -> FolderNode {
        let subfolders = folder.subfolders.map { createFolderNode(from: $0) }
        let conversations = fetchConversations(for: folder)
        return FolderNode(folder: folder, subfolders: subfolders, conversations: conversations)
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
}

struct FolderNode: Identifiable {
    let id = UUID()
    let folder: Folder
    let subfolders: [FolderNode]
    let conversations: [Conversation]
}
