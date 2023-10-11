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
    return VStack {
      Text("Template format").font(.title2)
      if let modelName = model.name {
        Text(modelName).font(.subheadline).foregroundStyle(.secondary)
      }
      Picker("", selection: $selection) {
        Format(TemplateManager.formatFromModel(model.name), title: "Auto (\(formatTitle(TemplateManager.formatFromModel(model.name))))")
        ForEach(TemplateFormat.allCases, id: \.self) { format in
          Format(format, title: formatTitle(format))
        }
      }.pickerStyle(.radioGroup)
        .onChange(of: selection) { next in
          print(model)
          model.promptTemplate = next?.rawValue
          do {
            try viewContext.save()
          } catch {
            print("Error saving prompt template: \(error.localizedDescription)")
          }
        }
      Button("Done") {
        dismiss()
      }.frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 10)
    }.padding()
      .onAppear() {
        if selection == nil, let templateName = model.promptTemplate {
          selection = TemplateFormat(rawValue: templateName)
        }
      }
      .frame(maxWidth: 500)
  }
  
  func Format(_ format: TemplateFormat, title: String) -> some View {
    let template = TemplateManager.templates[format]
    return VStack(alignment: .leading) {
      Text(title).font(.headline)
      Text(template.run(systemPrompt: "{{system prompt}}", messages: ["hi, bot"])
        .trimmingCharacters(in: .whitespacesAndNewlines))
        .foregroundColor(.secondary)
        .font(.monospaced(.body)())
    }.padding(.vertical, 4)
      .id(title)
      .tag(title.hasPrefix("Auto ") ? nil : format)
  }
  
  func formatTitle(_ format: TemplateFormat) -> String {
    switch format {
      case .alpaca:
        "Alpaca"
      case .chatML:
        "ChatML"
      case .llama2:
        "Llama 2"
      case .vicuna:
        "Vicuna"
    }

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
