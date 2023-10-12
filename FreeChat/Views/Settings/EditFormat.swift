//
//  EditFormat.swift
//  FreeChat
//
//  Created by Peter Sugihara on 10/10/23.
//

import SwiftUI

struct EditFormat: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.managedObjectContext) var viewContext

  @State var selection: TemplateFormat?
  
  var model: Model
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Prompt format").font(.body)
      if let modelName = model.name {
        Text("for \(modelName)").font(.caption).foregroundStyle(.secondary)
      }
      Picker("", selection: $selection) {
        Format(TemplateManager.formatFromModel(model.name), title: "Auto (\(TemplateManager.formatTitle(TemplateManager.formatFromModel(model.name))))")
        ForEach(TemplateFormat.allCases, id: \.self) { format in
          Format(format, title: TemplateManager.formatTitle(format))
        }
      }
      .padding(.top, 8)
      .pickerStyle(.menu)
        .labelsHidden()
        .onChange(of: selection) { next in
          model.promptTemplate = next?.rawValue
          do {
            try viewContext.save()
          } catch {
            print("Error saving prompt template: \(error.localizedDescription)")
          }
        }

      Text(templateText())
        .foregroundColor(.secondary)
        .font(.monospaced(.caption)())
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(9, reservesSpace: true)
        .fixedSize(horizontal: false, vertical: false)
        .background(.gray.opacity(0.15))
        .textSelection(.enabled)

      Button("Done") {
        dismiss()
      }.frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 10)
        .keyboardShortcut(.defaultAction)
    }.padding()
      .padding(.horizontal, 2)
      .onAppear() {
        if selection == nil, let templateName = model.promptTemplate {
          selection = TemplateFormat(rawValue: templateName)
        }
      }
      .frame(minWidth: 360, maxWidth: 400)
  }
  
  func Format(_ format: TemplateFormat, title: String) -> some View {
    return VStack(alignment: .leading) {
      Text(title)
    }.padding(.vertical, 4)
      .id(title)
      .tag(title.hasPrefix("Auto ") ? nil : format)
  }

  func templateText() -> String {
    let format = selection ?? TemplateManager.formatFromModel(model.name)
    let template = TemplateManager.templates[format]
    return template.run(systemPrompt: "{{system prompt}}", messages: ["hi, bot"]).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

#Preview {
  let ctx = PersistenceController.preview.container.viewContext
  let m = Model(context: ctx)
  m.name = "llama-2-13b-instruct.gguf"
  m.id = UUID()
  
  return EditFormat(model: m)
    .environment(\.managedObjectContext, ctx)
}
