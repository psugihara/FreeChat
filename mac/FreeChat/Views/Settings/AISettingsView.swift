//
//  AISettingsView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 12/9/23.
//

import SwiftUI
import Combine

struct AISettingsView: View {
  static let title = "Intelligence"
  private static let customizeModelsId = "customizeModels"

  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject var conversationManager: ConversationManager

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>

  @AppStorage("selectedModelId") private var selectedModelId: String = Model.unsetModelId
  @AppStorage("systemPrompt") private var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength = Agent.DEFAULT_CONTEXT_LENGTH
  @AppStorage("temperature") private var temperature: Double = Agent.DEFAULT_TEMP
  @AppStorage("useGPU") private var useGPU = Agent.DEFAULT_USE_GPU

  @State var pickedModel: String = Model.unsetModelId
  @State var customizeModels = false
  @State var editSystemPrompt = false
  @State var editFormat = false
  @State var revealAdvanced = false

  @StateObject var gpu = GPU.shared

  let contextLengthFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    return formatter
  }()

  let temperatureFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 0
    return formatter
  }()


  var selectedModel: Model? {
    if selectedModelId == Model.unsetModelId {
      models.first
    } else {
      models.first { i in i.id?.uuidString == selectedModelId }
    }
  }

  var systemPromptEditor: some View {
    VStack {
      HStack {
        Text("System prompt")
        Spacer()
        Button(action: {
          editSystemPrompt.toggle()
        }, label: {
          Text("Customize")
        })
        .padding(.leading, 10)
      }
      Text(systemPrompt)
        .font(.callout)
        .multilineTextAlignment(.leading)
        .lineLimit(6, reservesSpace: false)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
        .padding(.top, 0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  var modelPicker: some View {
    VStack(alignment: .leading) {
      Picker("Model", selection: $pickedModel) {
        ForEach(models) { i in
          if let url = i.url {
            Text(i.name ?? url.lastPathComponent)
              .tag(i.id?.uuidString ?? "")
              .help(url.path)
          }
        }

        Divider().tag(Model.unsetModelId)
        Text("Add or remove models...").tag(AISettingsView.customizeModelsId)
      }.onReceive(Just(pickedModel)) { _ in
        if pickedModel == AISettingsView.customizeModelsId {
          customizeModels = true
          pickedModel = selectedModelId
        } else if pickedModel != Model.unsetModelId {
          selectedModelId = pickedModel
        }
      }


      Text("The default model is general purpose, small, and works on most computers. Larger models are slower but wiser. Some models specialize in certain tasks like coding Python. FreeChat is compatible with most models in GGUF format. [Find new models](https://huggingface.co/models?search=GGUF)")
        .font(.callout)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
        .lineLimit(5)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 0.5)

      if let model = selectedModel {
        HStack {
          Text("Prompt format: \(TemplateManager.formatTitle(model.template.format))")
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .font(.caption)
          Button("Edit") {
            editFormat = true
          }.buttonStyle(.link).font(.caption)
            .offset(x: -4)
        }
          .sheet(isPresented: $editFormat, content: {
          EditFormat(model: model)
        })
      }
    }
  }

  var body: some View {
    Form {
      Section {
        systemPromptEditor
        modelPicker
      }
      Section {
        DisclosureGroup(isExpanded: $revealAdvanced, content: {
          VStack(alignment: .leading) {
            HStack {
              Text("Configure llama.cpp based on the model you're using.")
                .foregroundColor(Color(NSColor.secondaryLabelColor))
              Button("Restore defaults") {
                contextLength = Agent.DEFAULT_CONTEXT_LENGTH
                temperature = Agent.DEFAULT_TEMP
              }.buttonStyle(.link)
                .offset(x: -5.5)
            }.font(.callout)
              .padding(.top, 2.5)
              .padding(.bottom, 4)

            Divider()

            HStack {
              Text("Context Length")
              TextField("", value: $contextLength, formatter: contextLengthFormatter)
                .padding(.vertical, -8)
                .padding(.trailing, -10)
            }
            .padding(.top, 0.5)

            Divider()

            HStack {
              Text("Temperature")
              Slider(value: $temperature, in: 0...2, step: 0.1).offset(y: 1)
              Text("\(temperatureFormatter.string(from: temperature as NSNumber) ?? "")")
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .frame(width: 24, alignment: .trailing)
            }.padding(.top, 1)

            if gpu.available {
              Divider()

              Toggle("Use GPU Acceleration", isOn: $useGPU).padding(.top, 1)
            }
          }
        }, label: {
          Button() {
            withAnimation {
              revealAdvanced.toggle()
            }
          } label: {
            Text("Advanced Options")
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(.white.opacity(0.0001))
          }
          .buttonStyle(.plain)
        })
      }
    }
      .formStyle(.grouped)
      .sheet(isPresented: $customizeModels) {
        EditModels(selectedModelId: $selectedModelId)
      }
      .sheet(isPresented: $editSystemPrompt) {
        EditSystemPrompt()
      }
      .navigationTitle(AISettingsView.title)
      .onAppear {
        pickedModel = selectedModelId
      }
      .onChange(of: selectedModelId) { newModelId in
        pickedModel = newModelId
        var model: Model?
        if newModelId == Model.unsetModelId {
          model = models.first
        } else {
          model = models.first { i in i.id?.uuidString == newModelId }
        }
        guard let model else {
          return
        }

        conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
      }
      .onChange(of: systemPrompt) { nextPrompt in
        let model: Model? = selectedModel
        guard let model else {
          return
        }

        conversationManager.rebootAgent(systemPrompt: nextPrompt, model: model, viewContext: viewContext)
      }
      .onChange(of: useGPU) { nextUseGPU in
        let model: Model? = selectedModel
        guard let model else {
          return
        }

        conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
      }
      .frame(minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400, alignment: .center)
  }
}

#Preview {
  AISettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
