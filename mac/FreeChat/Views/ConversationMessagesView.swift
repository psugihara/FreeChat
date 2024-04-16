//
//  ConversationMessagesView.swift
//  FreeChat
//
//  Created by Bogdan Protsenko on 13/04/2024.
//

import SwiftUI
import WebKit
import libcmark_gfm

struct ConversationMessagesView: NSViewRepresentable {
  // MARK: - Properties
  
  var htmlContent: String = ""
  var overrideText: String
  let agentStatus: Agent.Status?
  let host = "https://www.otherbrain.world"

  @Environment(\.managedObjectContext) private var viewContext
  @Binding var messages: [Message]
  @AppStorage("showFeedbackButtons") private var showFeedbackButtons = true
  
  // MARK: - Initialization
  
  init(messages: Binding<[Message]>, overrideText: String = "", agentStatus: Agent.Status?) {
    cmark_gfm_core_extensions_ensure_registered()
    self._messages = messages
    self.overrideText = overrideText
    self.agentStatus = agentStatus
  }

  // MARK: - NSViewRepresentable
  
  func makeNSView(context: Context) -> WKWebView  {
    let userContentController = makeUserContentController(context: context)
    let webViewConfiguration = makeWebViewConfiguration(userContentController: userContentController)
    let webView = makeWebView(configuration: webViewConfiguration)
    
    context.coordinator.webView = webView
    
    return webView
  }
  
  func updateNSView(_ nsView: WKWebView, context: Context) {
    loadHTMLContent(in: nsView)
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  // MARK: - Private Methods
  
  private func makeUserContentController(context: Context) -> WKUserContentController {
    let userContentController = WKUserContentController()
    userContentController.add(context.coordinator, name: "feedbackAction")
    return userContentController
  }
  
  private func makeWebViewConfiguration(userContentController: WKUserContentController) -> WKWebViewConfiguration {
    let webViewConfiguration = WKWebViewConfiguration()
    webViewConfiguration.userContentController = userContentController
    return webViewConfiguration
  }
  
  private func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.setValue(false, forKey: "drawsBackground")
    
    if #available(macOS 13.3, *) {
      webView.isInspectable = true
    }
    
    return webView
  }
  
  private func loadHTMLContent(in webView: WKWebView) {
    guard let htmlPath = Bundle.main.path(forResource: "ConversationMessagesView", ofType: "html") else {
      return
    }
    
    let url = URL(fileURLWithPath: htmlPath)
    
    do {
      let baseView = try String(contentsOf: url, encoding: .utf8)
      let messagesView = renderMessages()
      let html = baseView.replacingOccurrences(of: "%MESSAGES%", with: messagesView)
      
      webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    } catch {
      print("Unable to load HTML content: \(error)")
    }
  }
  
  private func renderMessages() -> String {
    var messagesView = ""
    
    for message in messages {
      messagesView += renderMessage(message: message)
    }
    
    return messagesView
  }
  
  private func renderMessage(message: Message) -> String {
    guard let text = message.text, !text.isEmpty else {
      return "<p>Pending...</p>"
    }
    
    let idString = message.uuid.uuidString
    let isLastMessage = message == messages.last
    let infoText = getInfoText(for: message, isLastMessage: isLastMessage)
    let info = getInfo(for: message)
    let miniInfo = getMiniInfo(for: message)
    let advancedDetailsMenuItem = getAdvancedDetailsMenuItem(for: message)
    let feedbackButton = getFeedbackButton(for: message)
    
    return """
    <div data-id="\(idString)" class="message-view">
      <svg class="avatar"><use href="#user-avatar"></use></svg>
      <div class="content">
        <div class="info-line">
          <span class="mini-info">
            <span class="info-text">\(infoText)</span>
            <button class="menu-button" onclick="showMenu('\(idString)')">
              <svg class="menu-icon"><use href="#circle-ellipsis"></use></svg>
              <menu>
                \(advancedDetailsMenuItem)
                <li onclick="copyMessage('\(idString)')">Copy message</li>
              </menu>
              <span class="popover">
                \(info)
              </span>
            </button>
            <span>
              \(miniInfo)
            </span>
          </span>
          \(feedbackButton)
        </div>
        <div class="message-text">
          \(self.renderMarkdownHTML(markdown: text) ?? "")
        </div>
      </div>
    </div>
    """
  }
  
  private func getInfoText(for message: Message, isLastMessage: Bool) -> String {
    if isLastMessage && agentStatus == .coldProcessing && overrideText.isEmpty {
      return "warming up..."
    } else {
      return messageTimestampFormatter.string(from: message.createdAt ?? Date())
    }
  }
  
  private func getInfo(for message: Message) -> String {
    var parts: [String] = []
    
    if message.responseStartSeconds > 0 {
      parts.append("Response started in: \(String(format: "%.3f", message.responseStartSeconds)) seconds")
    }
    if message.nPredicted > 0 {
      parts.append("Tokens generated: \(String(format: "%d", message.nPredicted))")
    }
    if message.predictedPerSecond > 0 {
      parts.append("Tokens generated per second: \(String(format: "%.3f", message.predictedPerSecond))")
    }
    if let modelName = message.modelName, !modelName.isEmpty {
      parts.append("Model: \(modelName)")
    }
    
    return parts.joined(separator: "\n")
  }
  
  private func getMiniInfo(for message: Message) -> String {
    var parts: [String] = []
    
    if let ggufCut = try? Regex(".gguf$"),
       let modelName = message.modelName?.replacing(ggufCut, with: "") {
      parts.append("\(modelName)")
    }
    if message.predictedPerSecond > 0 {
      parts.append("\(String(format: "%.1f", message.predictedPerSecond)) tokens/s")
    }
    
    return parts.joined(separator: ", ")
  }
  
  private func getAdvancedDetailsMenuItem(for message: Message) -> String {
    return message.fromId != Message.USER_SPEAKER_ID ? """
    <li onclick="showAdvancedDetails('\(message.uuid.uuidString)')">Advanced details</li>
    """ : ""
  }
  
  private func getFeedbackButton(for message: Message) -> String {
    guard showFeedbackButtons else {
      return ""
    }
    
    let idString = message.uuid.uuidString
    let upIcon = message.feedbackId != nil && message.feedbackId != FeedbackButton.PENDING_FEEDBACK_ID ? "✓" : "👍"
    let downIcon = message.feedbackId != nil && message.feedbackId != FeedbackButton.PENDING_FEEDBACK_ID ? "✓" : "👎"
    
    return """
    <button class="feedback-button" onclick="handleFeedback('\(idString)', 'up')">
      \(upIcon)
    </button>
    <button class="feedback-button" onclick="handleFeedback('\(idString)', 'down')">
      \(downIcon)
    </button>
    """
  }
  
  private let messageTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }()
  
  private func renderMarkdownHTML(markdown: String) -> String? {
    let markdown = markdown.replacingOccurrences(of: "{{TOC}}", with: "<div id=\"toc\"></div>")
    
    guard let parser = cmark_parser_new(CMARK_OPT_FOOTNOTES) else { return nil }
    defer { cmark_parser_free(parser) }
    
    let extensions = ["table", "autolink", "strikethrough", "tasklist"]
    
    for extensionName in extensions {
      if let ext = cmark_find_syntax_extension(extensionName) {
        cmark_parser_attach_syntax_extension(parser, ext)
      }
    }
    
    cmark_parser_feed(parser, markdown, markdown.utf8.count)
    guard let node = cmark_parser_finish(parser) else { return nil }
    return String(cString: cmark_render_html(node, CMARK_OPT_HARDBREAKS | CMARK_OPT_UNSAFE, nil))
  }
  
  
  // MARK: - Coordinator
  
  class Coordinator: NSObject, WKScriptMessageHandler {
    var parent: ConversationMessagesView
    var webView: WKWebView?
    
    init(_ parent: ConversationMessagesView) {
      self.parent = parent
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard message.name == "feedbackAction",
            let body = message.body as? [String: Any],
            let messageId = body["messageId"] as? String,
            let thumbDirection = body["thumbDirection"] as? String else {
        return
      }
      
      parent.handleFeedback(messageId: messageId, thumbDirection: thumbDirection)
    }
  }
  
  // MARK: - Feedback Handling
  
  func handleFeedback(messageId: String, thumbDirection: String) {
    guard let uuid = UUID(uuidString: messageId),
          let message = messages.first(where: { $0.uuid == uuid }) else {
      print("Evaluated messageId: \(messageId)")
      print("Message UUIDs:")
      for message in messages {
        print(message.uuid)
      }
      return
    }
    
    if let feedbackId = message.feedbackId,
       feedbackId != FeedbackButton.PENDING_FEEDBACK_ID,
       let url = URL(string: "\(host)/api/label-human-feedback/\(feedbackId)") {
      NSWorkspace.shared.open(url)
    } else {
      postFeedback(message: message, thumbDirection: thumbDirection)
    }
  }
  
  func postFeedback(message: Message, thumbDirection: String) {
    message.feedbackId = FeedbackButton.PENDING_FEEDBACK_ID
    
    let messages = message.conversation?.orderedMessages
      .filter { $0.createdAt == nil || message.createdAt == nil || $0.createdAt! <= message.createdAt! }
      .map { HumanFeedbackMessage(fromUser: $0.fromId == Message.USER_SPEAKER_ID, text: $0.text ?? "") }
    let feedback = HumanFeedback(
      messages: messages ?? [],
      modelName: message.modelName ?? "",
      promptTemplate: message.promptTemplate ?? "",
      lastSystemPrompt: message.systemPrompt ?? "",
      quality: thumbDirection == "up" ? 5 : 1
    )
    
    Task {
      await postFeedbackRequest(feedback: feedback, message: message)
    }
  }
  
  private func postFeedbackRequest(feedback: HumanFeedback, message: Message) async {
    guard let url = URL(string: "\(host)/api/human-feedback") else {
      return
    }
    
    do {
      var request = URLRequest(url: url)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpMethod = "POST"
      let encoder = JSONEncoder()
      
      let data = try encoder.encode(feedback)
      request.httpBody = data
      let (responseData, response) = try await URLSession.shared.data(for: request)
      
      #if DEBUG
      print("response", response)
      #endif
      
      let statusCode = (response as! HTTPURLResponse).statusCode
      
      if statusCode == 200,
         let json = try? JSONDecoder().decode(HumanFeedbackResponse.self, from: responseData) {
        message.feedbackId = json.id
        try viewContext.save()
        
        if let feedbackId = message.feedbackId,
           let url = URL(string: "\(host)/api/label-human-feedback/\(feedbackId)") {
          NSWorkspace.shared.open(url)
        }
      } else {
        print("FAILURE")
      }
    } catch {
      print("error posting to \(url.debugDescription)", error.localizedDescription)
    }
    
    if message.feedbackId == FeedbackButton.PENDING_FEEDBACK_ID {
      message.feedbackId = nil
    }
  }
}
