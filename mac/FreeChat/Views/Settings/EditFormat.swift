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

  @AppStorage("remoteModelTemplate") var remoteModelTemplate: String?
  @State private var selection: TemplateFormat?

  private var modelID: UUID? // For local models only
  private var modelName: String?
  private var modelTemplate: String?

  init(model: Model) {
    self.modelID = model.id
    self.modelName = model.name
    self.modelTemplate = model.promptTemplate
 }

  init(modelName: String) {
    self.modelID = nil
    self.modelName = modelName
    self.modelTemplate = remoteModelTemplate
  }

  var templateText: String {
    let format = selection ?? TemplateManager.formatFromModel(modelName)
    let template = TemplateManager.templates[format]
    return template.run(systemPrompt: "{{system prompt}}", messages: ["hi, bot"]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Prompt format").font(.body)
      if let modelName = self.modelName {
        Text("for \(modelName)")
          .font(.caption).foregroundStyle(.secondary)
      }
      Picker("", selection: $selection) {
        Format(TemplateManager.formatFromModel(modelName), title: "Auto (\(TemplateManager.formatFromModel(modelName).rawValue))")
        ForEach(TemplateFormat.allCases, id: \.self) { format in
          Format(format, title: format.rawValue)
        }
      }
      .padding(.top, 8)
      .pickerStyle(.menu)
      .labelsHidden()
      .onChange(of: selection) { next in
        guard let template = next?.rawValue else { return }
        if let modelID = self.modelID {
          saveTemplate(modelID: modelID, template: template)
        } else {
          saveTemplate(template: template)
        }
      }

      Text(templateText)
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
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.top, 10)
      .keyboardShortcut(.defaultAction)
    }
    .padding()
    .padding(.horizontal, 2)
    .onAppear() {
        if selection == nil, let templateName = modelTemplate {
          selection = TemplateFormat(rawValue: templateName)
        }
      }
      .frame(minWidth: 360, maxWidth: 400)
  }

  func Format(_ format: TemplateFormat, title: String) -> some View {
    VStack(alignment: .leading) {
      Text(title)
    }
    .padding(.vertical, 4)
    .id(title)
    .tag(title.hasPrefix("Auto ") ? nil : format)
  }

  private func saveTemplate(modelID: UUID, template: String) {
    let req = Model.fetchRequest()
    req.predicate = NSPredicate(format: "id == %@", modelID as CVarArg)
    do {
      if let model = try viewContext.fetch(req).first {
        model.promptTemplate = template
        try viewContext.save()
      } else {
        print("Error finding model with id \(modelID)")
      }
    } catch {
      print("Error saving prompt template: \(error.localizedDescription)")
    }
  }

  private func saveTemplate(template: String) {
    remoteModelTemplate = template
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
