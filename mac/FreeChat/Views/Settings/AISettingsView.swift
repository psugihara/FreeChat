//
//  AISettingsView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 12/9/23.
//

import Combine
import SwiftUI

struct AISettingsView: View {
  static let title = "Intelligence"
  private static let customizeModelsId = "customizeModels"
  private let serverHealthTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject var conversationManager: ConversationManager

  @available(*, deprecated, message: "use modelList instead")
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>

  @AppStorage("backendTypeID") private var backendTypeID: String?
  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("systemPrompt") private var systemPrompt = DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength = DEFAULT_CONTEXT_LENGTH
  @AppStorage("temperature") private var temperature: Double = DEFAULT_TEMP
  @AppStorage("useGPU") private var useGPU = DEFAULT_USE_GPU
  @AppStorage("serverTLS") private var serverTLS: Bool = false
  @AppStorage("serverHost") private var serverHost: String?
  @AppStorage("serverPort") private var serverPort: String?
  @AppStorage("openAIToken") private var openAIToken: String?
  @AppStorage("remoteModelTemplate") var remoteModelTemplate: String?

  @State var pickedModel: String?  // Picker selection
  @State var customizeModels = false  // Show add remove models
  @State var editSystemPrompt = false
  @State var editFormat = false
  @State var revealAdvanced = false
  @State var inputServerHost: String = ""
  @State var inputServerPort: String = ""
  @State var serverHealthScore: Double = -1
  @State var modelList: [String] = []

  @StateObject var gpu = GPU.shared

  private var isUsingLocalServer: Bool { 
    backendTypeID == BackendType.local.rawValue
  }

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

  
  @available(*, deprecated, message: "use selectedModelName instead")
  var selectedModel: Model? {
    if let selectedModelId {
      models.first(where: { $0.id?.uuidString == selectedModelId })
    } else {
      models.first
    }
  }
  
  var selectedModelName: String? {
    modelList.first
  }

  var systemPromptEditor: some View {
    VStack {
      HStack {
        Text("System prompt")
        Spacer()
        Button {
          editSystemPrompt.toggle()
        } label: {
          Text("Customize")
        }
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

  var backendTypePicker: some View {
    HStack {
      Picker("Backend", selection: $backendTypeID) {
        ForEach(BackendType.allCases, id: \.self) { name in
          Text(name.rawValue).tag(name.rawValue as String?)
        }
      }
      .onAppear {
        if backendTypeID == nil {
          backendTypeID = BackendType.local.rawValue
        }
      }
      .onChange(of: backendTypeID) {
        NotificationCenter.default.post(name: NSNotification.Name("backendTypeIDDidChange"), object: $0)
        Task {
          do {
            try await fetchModels()
            // TODO: This is temporary just to list the models
            pickedModel = modelList.first
          } catch let error {
            print("error fetching models:", error)
          }
        }
      }
    }
  }

  var editPromptFormat: some View {
    HStack {
      if let model = selectedModel {
        Text("Prompt format: \(model.template.format.rawValue)")
          .foregroundColor(Color(NSColor.secondaryLabelColor))
          .font(.caption)
      } else if !isUsingLocalServer {
        Text("Prompt format: \(remoteModelTemplate ?? TemplateFormat.vicuna.rawValue)")
          .foregroundColor(Color(NSColor.secondaryLabelColor))
          .font(.caption)
      }
      Button("Edit") {
        editFormat = true
      }
      .buttonStyle(.link).font(.caption)
      .offset(x: -4)
    }
    .sheet(isPresented: $editFormat) {
      if let model = selectedModel {
        EditFormat(model: model)
      } else if !isUsingLocalServer {
        EditFormat(modelName: "Remote")
      }
    }
  }

  var modelPicker: some View {
    VStack(alignment: .leading) {
      Picker("Model", selection: $pickedModel) {
        // TODO: Format the models
        ForEach(modelList, id: \.self) {
          Text($0)
            .tag($0 as String?)
            .help($0)
        }
//        ForEach(models) { i in
//          if let url = i.url {
//            Text(i.name ?? url.lastPathComponent)
//              .tag(i.id?.uuidString)
//              .help(url.path)
//          }
//        }

        if isUsingLocalServer {
          Divider().tag(nil as String?)
          Text("Add or Remove Models...").tag(AISettingsView.customizeModelsId as String?)
        }
      }
      .onAppear {
        Task { try? await fetchModels() }
      }
      .onReceive(Just(pickedModel)) { _ in
        switch pickedModel {
        case AISettingsView.customizeModelsId:
          customizeModels = true
        case .some(let pickedModelValue):
          customizeModels = false
          selectedModelId = pickedModelValue
        default: break
        }
      }
      .onChange(of: pickedModel) { newValue in
        switch pickedModel {
        case AISettingsView.customizeModelsId:
          customizeModels = true
        case .some(let pickedModelValue):
          customizeModels = false
          selectedModelId = pickedModelValue
        default: break
        }
      }

      if isUsingLocalServer {
        Text(
          "The default model is general purpose, small, and works on most computers. Larger models are slower but wiser. Some models specialize in certain tasks like coding Python. FreeChat is compatible with most models in GGUF format. [Find new models](https://huggingface.co/models?search=GGUF)"
        )
        .font(.callout)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
        .lineLimit(5)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 0.5)
      } else {
        Text(
          "If you have access to a powerful server, you may want to run your model there. Enter the host and port to connect to a remote llama.cpp server. Instructions for running the server can be found [here](https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md)"
        )
        .font(.callout)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
        .lineLimit(5)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 0.5)
      }
      editPromptFormat
    }
  }

  var hasRemoteServerInputChanged: Bool {
    inputServerHost != serverHost || inputServerPort != serverPort
  }
  var hasRemoteConnectionError: Bool {
    serverHealthScore < 0.25 && serverHealthScore >= 0
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

  var serverHealthIndication: some View {
    VStack {
      HStack {
        Circle()
          .frame(width: 9, height: 9)
          .foregroundColor(indicatorColor)
        Group {
          switch serverHealthScore {
          case 0.25...1:
            Text("Connected")
          case 0..<0.25:
            Text("Connection Error. Retrying...")
          default:
            Text("Not Connected")
          }
        }
        .font(.callout)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
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

  var sectionRemoteBackend: some View {
    Group {
      HStack {
        TextField("Server host", text: $inputServerHost, prompt: Text("yourserver.net"))
          .textFieldStyle(.plain)
          .font(.callout)
        TextField("Server port", text: $inputServerPort, prompt: Text("3000"))
          .textFieldStyle(.plain)
          .font(.callout)
        Spacer()
      }
      Toggle(isOn: $serverTLS) {
        Text("Secure connection (HTTPS)")
          .font(.callout)
      }
      HStack {
        serverHealthIndication
        Spacer()
        Button("Apply", action: saveFormRemoteServer)
          .disabled(!hasRemoteServerInputChanged && !hasRemoteConnectionError)
      }
    }
  }

  var body: some View {
    Form {
      Section {
        systemPromptEditor
        backendTypePicker
        modelPicker
        if !isUsingLocalServer {
          sectionRemoteBackend
        }
      }
      Section {
        DisclosureGroup(
          isExpanded: $revealAdvanced,
          content: {
            VStack(alignment: .leading) {
              HStack {
                Text("Configure llama.cpp based on the model you're using.")
                  .foregroundColor(Color(NSColor.secondaryLabelColor))
                Button("Restore defaults") {
                  contextLength = DEFAULT_CONTEXT_LENGTH
                  temperature = DEFAULT_TEMP
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

              if gpu.available && isUsingLocalServer {
                Divider()

                Toggle("Use GPU Acceleration", isOn: $useGPU).padding(.top, 1)
              }
            }
          },
          label: {
            Button {
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
    .sheet(isPresented: $customizeModels, onDismiss: { pickedModel = selectedModelId }) {
      EditModels(selectedModelId: $selectedModelId)
    }
    .sheet(isPresented: $editSystemPrompt) {
      EditSystemPrompt()
    }
    .onSubmit(saveFormRemoteServer)
    .navigationTitle(AISettingsView.title)
    .onAppear {
      if isUsingLocalServer {
        let selectedModelExists =
          models
          .compactMap({ $0.id?.uuidString })
          .contains(selectedModelId)
        if !selectedModelExists {
          selectedModelId = models.first?.id?.uuidString
        }
      }
      pickedModel = selectedModelId
      inputServerHost = serverHost ?? ""
      inputServerPort = serverPort ?? ""
      updateRemoteServerURL()
    }
    .onChange(of: selectedModelId) { newModelId in
      pickedModel = newModelId
      guard
        let model = models.first(where: { $0.id?.uuidString == newModelId }) ?? models.first
      else { return }

      conversationManager.rebootAgent(
        systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
    }
    .onChange(of: systemPrompt) { nextPrompt in
      guard let model: Model = selectedModel else { return }
      conversationManager.rebootAgent(
        systemPrompt: nextPrompt, model: model, viewContext: viewContext)
    }
    .onChange(of: useGPU) { nextUseGPU in
      guard let model: Model = selectedModel else { return }
      conversationManager.rebootAgent(
        systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSNotification.Name("selectedModelDidChange"))
    ) { output in
      if let updatedId: String = output.object as? String {
        selectedModelId = updatedId
      }
    }
    .frame(
      minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400,
      alignment: .center)
  }

  private func saveFormRemoteServer() {
    serverHost = inputServerHost
    serverPort = inputServerPort
    serverHealthScore = -1
    updateRemoteServerURL()
  }

  private func updateRemoteServerURL() {
    let scheme = serverTLS ? "https" : "http"
    guard let url = URL(string: "\(scheme)://\(inputServerHost):\(inputServerPort)")
    else { return }
    Task {
      await ServerHealth.shared.updateURL(url)
      await ServerHealth.shared.check()
    }
  }

  //  MARK: - Fetch models

  private func fetchModels() async throws {
    let backendType: BackendType = BackendType(rawValue: backendTypeID ?? "") ?? .local
    let baseURL: URL
    if let serverHost, let serverPort {
      baseURL = URL(string: "\(serverTLS ? "https" : "http")://\(serverHost):\(serverPort)")!
    } else {
      baseURL = BackendType.local.defaultURL
    }

    switch backendType {
    case .local:
      let baseURL = BackendType.local.defaultURL
      let backend = LocalBackend(contextLength: 0, baseURL: baseURL, apiKey: nil)
      modelList = try await backend.listModels()
    case .llama:
      let backend = LlamaBackend(contextLength: 0, baseURL: baseURL, apiKey: openAIToken)
      modelList = try await backend.listModels()
    case .openai:
      let backend = OpenAIBackend(contextLength: 0, baseURL: baseURL, apiKey: openAIToken)
      modelList = backend.listModels()
    case .ollama:
      let backend = OllamaBackend(contextLength: 0, baseURL: baseURL, apiKey: openAIToken)
      modelList = try await backend.listModels()
    }
  }
}

#Preview{
  AISettingsView()
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
