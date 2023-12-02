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

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)],
    animation: .default)
  private var items: FetchedResults<Conversation>

  @Binding var selection: Set<Conversation>
  @Binding var showDeleteConfirmation: Bool

  @State var editing: Conversation?
  @State var newTitle = ""
  @FocusState var fieldFocused

  var body: some View {
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
