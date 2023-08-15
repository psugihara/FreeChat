//
//  ConversationNavItem.swift
//  Chats
//
//  Created by Peter Sugihara on 8/5/23.
//

import SwiftUI

struct NavList: View {
  @Environment(\.managedObjectContext) private var viewContext
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Conversation>
  
  @Binding var selection: Set<Conversation>
  
  @State var editing: Conversation?
  @State var newTitle = ""
  @FocusState var fieldFocused
  
  var body: some View {
    List(sortedItems(), id: \.self, selection: $selection) { item in
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
          .padding(.trailing, 6)
      } else {
        Text(item.titleWithDefault).padding(.leading, 4)
      }
    }
    .frame(minWidth: 50)
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
    .onChange(of: items.count) { _ in
      selection = Set([sortedItems().first].compactMap { $0 })
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
  }
  
  private func saveNewTitle(conversation: Conversation) {
    conversation.title = newTitle
    do {
      try viewContext.save()
    } catch {
      // Replace this implementation with code to handle the error appropriately.
      // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
      let nsError = error as NSError
      fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
    }
  }
  
  private func deleteSelectedConversations() {
    withAnimation {
      selection.forEach(viewContext.delete)
      do {
        try viewContext.save()
        selection = Set()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
  
  private func addConversation() {
    withAnimation {
      do {
        _ = try Conversation.create(ctx: viewContext)
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
  
  private func deleteConversation(conversation: Conversation) {
    withAnimation {
      viewContext.delete(conversation)
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
  
  private func sortedItems() -> [FetchedResults<Conversation>.Element] {
    items.sorted(by: { $0.updatedAt!.compare($1.updatedAt!) == .orderedDescending })
  }
}

#if DEBUG
struct NavList_Previews_Container : View {
  @State public var selection: Set<Conversation> = Set()
  
  var body: some View {
    NavList(selection: $selection)
      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}

struct NavList_Previews: PreviewProvider {
  static var previews: some View {
    NavList_Previews_Container()
  }
}
#endif
