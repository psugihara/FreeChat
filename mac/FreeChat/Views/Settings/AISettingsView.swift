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

  private let serverHealthTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject var conversationManager: ConversationManager

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>

  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("systemPrompt") private var systemPrompt = Agent.DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength = Agent.DEFAULT_CONTEXT_LENGTH
  @AppStorage("temperature") private var temperature: Double = Agent.DEFAULT_TEMP
  @AppStorage("useGPU") private var useGPU = Agent.DEFAULT_USE_GPU
  @AppStorage("serverTLS") private var serverTLS: Bool = false
  @AppStorage("serverHost") private var serverHost: String?
  @AppStorage("serverPort") private var serverPort: String?

  @State var pickedModel: String? // Picker selection
  @State var customizeModels = false // Show add remove models
  @State var editSystemPrompt = false
  @State var editFormat = false
  @State var revealAdvanced = false
  @State var inputServerTLS: Bool = false
  @State var inputServerHost: String = ""
  @State var inputServerPort: String = ""
  @State var serverHealthScore: Double = -1

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
    if let selectedModelId = self.selectedModelId {
      models.first(where: { $0.id?.uuidString == selectedModelId })
    } else {
      models.first
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
              .tag(i.id?.uuidString)
              .help(url.path)
          }
        }

        Divider().tag(nil as String?)
        Text("Add or remove models...") .tag(AISettingsView.customizeModelsId as String?)
      }.onReceive(Just(pickedModel)) { _ in
        if pickedModel == AISettingsView.customizeModelsId {
          customizeModels = true
          pickedModel = selectedModelId
        } else if pickedModel != nil {
          selectedModelId = pickedModel
        }
      }
      .onChange(of: pickedModel) { newValue in
        if pickedModel == AISettingsView.customizeModelsId {
          customizeModels = true
          pickedModel = selectedModelId
        } else if pickedModel != nil {
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


  
  var indicatorColor: Color {
    switch serverHealthScore {
    case 0..<0.25:
      Color(red: 1, green: 0, blue: 0)
    case 0.25..<0.5:
      Color(red: 1, green: 0.5, blue: 0)
    case 0.5..<0.75:
      Color(red: 0.45, green: 0.55, blue: 0)
    case 0.75..<0.95:
      Color(red: 0.1, green: 0.9, blue: 0)
    case 0.95...1:
      Color(red: 0, green: 1, blue: 0)
    default:
      Color(red: 0.5, green: 0.5, blue: 0.5)
    }
  }

  var serverHealthIndicator: some View {
    Circle()
      .frame(width: 12, height: 12)
      .foregroundColor(indicatorColor)
  }

  var body: some View {
    Form {
      Section {
        systemPromptEditor
        modelPicker
        // TODO: Show indicator of health, precentage
        // using stats from last n responses
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
      Section {
        HStack {
          TextField("Server Host", text: $inputServerHost)
            .font(.callout)
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .lineLimit(5)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
          TextField("Server Port", text: $inputServerPort)
            .font(.callout)
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .lineLimit(5)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
        }
        Toggle(isOn: $inputServerTLS) {
          Text("Enable HTTPS")
            .font(.callout)
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .lineLimit(5)
        }
        .toggleStyle(CheckboxToggleStyle())
        HStack {
          serverHealthIndicator
          Text("Server health")
          Text(String(serverHealthScore))
        }
        .onReceive(serverHealthTimer) { _ in
          Task {
            await ServerHealth.shared.check()
            let score = await ServerHealth.shared.score
            serverHealthScore = score
          }
        }
      }
    }
      .formStyle(.grouped)
      .sheet(isPresented: $customizeModels) {
        EditModels(selectedModelId: $selectedModelId)
      }
      .sheet(isPresented: $editSystemPrompt) {
        EditSystemPrompt()
      }
      .onSubmit(saveFormRemoteServer)
      .navigationTitle(AISettingsView.title)
      .onAppear {
        let selectedModelExists = models
          .compactMap({ $0.id?.uuidString })
          .contains(selectedModelId)
        if !selectedModelExists {
          selectedModelId = models.first?.id?.uuidString
        }
        pickedModel = selectedModelId
        
        inputServerTLS = serverTLS
        inputServerHost = serverHost ?? ""
        inputServerPort = serverPort ?? ""
        updateRemoteServerURL()
      }
      .onChange(of: selectedModelId) { newModelId in
        pickedModel = newModelId
        guard
          let model = models.first(where: { $0.id?.uuidString == newModelId }) ?? models.first
        else { return }

        conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
      }
      .onChange(of: systemPrompt) { nextPrompt in
        guard let model: Model = selectedModel else { return }
        conversationManager.rebootAgent(systemPrompt: nextPrompt, model: model, viewContext: viewContext)
      }
      .onChange(of: useGPU) { nextUseGPU in
        guard let model: Model = selectedModel else { return }
        conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("selectedModelDidChange"))) { output in
        if let updatedId: String = output.object as? String {
          selectedModelId = updatedId
        }
      }
      .frame(minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400, alignment: .center)
  }

  private func saveFormRemoteServer() {
    // TODO: Validate input
    serverTLS = inputServerTLS
    serverHost = inputServerHost
    serverPort = inputServerPort
    serverHealthScore = -1
    // TODO: Display errors or success √
    updateRemoteServerURL()
  }

  private func updateRemoteServerURL() {
    let scheme = inputServerTLS ? "https" : "http"
    guard let url = URL(string: "\(scheme)://\(inputServerHost):\(inputServerPort)/health")
    else { return }
    Task {
      await ServerHealth.shared.updateURL(url)
      await ServerHealth.shared.check()
    }
  }
}

#Preview {
  AISettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
