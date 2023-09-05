//
//  EditSystemPrompt.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/3/23.
//

import SwiftUI

struct EditSystemPrompt: View {
  @Environment(\.dismiss) var dismiss

  @AppStorage("systemPrompt") private var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  @State private var pendingSystemPrompt = ""
  private var systemPromptPendingSave: Bool {
    pendingSystemPrompt != "" && pendingSystemPrompt != systemPrompt
  }
  @State private var didSaveSystemPrompt = false
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Edit the system prompt to customize behavior and personality.").font(.callout).padding(.horizontal, 8)
        .foregroundColor(.secondary)
      Group {
        TextEditor(text: $pendingSystemPrompt).onAppear {
          pendingSystemPrompt = systemPrompt
        }
        .frame(minWidth: 200,
               idealWidth: 250,
               maxWidth: .infinity,
               minHeight: 100,
               idealHeight: 120,
               maxHeight: .infinity,
               alignment: .center)
      }
      .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
      .background(Color("TextBackground"))
      
      HStack {
        Button("Restore Default") {
          pendingSystemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
        }
        .disabled(pendingSystemPrompt ==  Agent.DEFAULT_SYSTEM_PROMPT)
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
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.bottom)
    }.padding()
  }
}

struct EditSystemPrompt_Previews: PreviewProvider {
  static var previews: some View {
    let context = PersistenceController.preview.container.viewContext
    EditSystemPrompt().environment(\.managedObjectContext, context)
  }
}
