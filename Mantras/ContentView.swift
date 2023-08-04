//
//  ContentView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import CoreData

struct ContentView: View {
  @Environment(\.managedObjectContext) private var viewContext
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Conversation>

  let agent: Agent = Agent(id: "0", prompt: "")

  var body: some View {
    NavigationView {
      List(items) { item in
          NavigationLink {
            ConversationView(conversation: item, agent: agent)
          } label: {
            Text(item.createdAt!, formatter: itemFormatter)
          }.contextMenu {
            Button {
              deleteConversation(item)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
      }
      .toolbar {
        ToolbarItem {
          Spacer()
        }
        ToolbarItem {
          Button(action: addConversation) {
            Label("Add conversation", systemImage: "plus")
          }
        }
      }
      Text("Select a conversation")
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { output in
      print("will terminate")
      agent.llama.stopServer()
    })
  }
  
  private func addConversation() {
    withAnimation {
      let newConversation = Conversation(context: viewContext)
      newConversation.createdAt = Date()
      
      do {
        try viewContext.save()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
  
  private func deleteConversation(_ item: FetchedResults<Conversation>.Element) {
//    print("deleteConversation: ", multiSelection)
    withAnimation {
//      offsets.map { items[$0] }.forEach(viewContext.delete)
      viewContext.delete(item)
      do {
        try viewContext.save()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
}

private let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
