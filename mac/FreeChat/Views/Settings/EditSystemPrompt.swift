//
//  EditSystemPrompt.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/3/23.
//

import SwiftUI

struct EditSystemPrompt: View {
  @Environment(\.dismiss) var dismiss

  @AppStorage("systemPrompt") private var systemPrompt = DEFAULT_SYSTEM_PROMPT
  @State private var pendingSystemPrompt = ""
  private var systemPromptPendingSave: Bool {
    pendingSystemPrompt != "" && pendingSystemPrompt != systemPrompt
  }
  @State private var didSaveSystemPrompt = false
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Edit the system prompt to customize behavior and personality.").padding(.horizontal, 8)
        .foregroundColor(.secondary)
        .font(.body)
      Group {
        TextEditor(text: $pendingSystemPrompt).onAppear {
          pendingSystemPrompt = systemPrompt
        }
        .font(.body)
        .frame(minWidth: 200,
               idealWidth: 250,
               maxWidth: .infinity,
               minHeight: 100,
               idealHeight: 120,
               maxHeight: .infinity,
               alignment: .center)
        .scrollContentBackground(.hidden)
        .background(.clear)
      }
      .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
      .background(Color(NSColor.alternatingContentBackgroundColors.last ?? NSColor.controlBackgroundColor))
      
      HStack {
        Button("Restore Default") {
          pendingSystemPrompt = DEFAULT_SYSTEM_PROMPT
        }
        .disabled(pendingSystemPrompt ==  DEFAULT_SYSTEM_PROMPT)
        Spacer()
        Button("Cancel") {
          dismiss()
        }
        
        Button("Save") {
          systemPrompt = pendingSystemPrompt
          dismiss()
        }
        .disabled(!systemPromptPendingSave)
      }
      .frame(maxWidth: .infinity, alignment: .bottomTrailing)
    }.padding(10)
      .background(Color(NSColor.controlBackgroundColor))
  }
}

struct EditSystemPrompt_Previews: PreviewProvider {
  static var previews: some View {
    let context = PersistenceController.preview.container.viewContext
    EditSystemPrompt().environment(\.managedObjectContext, context)
  }
}
