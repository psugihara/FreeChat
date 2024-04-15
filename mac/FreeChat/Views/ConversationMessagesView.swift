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
  var htmlContent: String = ""
  var messages: [Message]
  var overrideText: String
  let agentStatus: Agent.Status?
  
  func renderMarkdownHTML(markdown: String) -> String? {
    let markdown = markdown.replacingOccurrences(of: "{{TOC}}", with: "<div id=\"toc\"></div>")
    
    guard let parser = cmark_parser_new(CMARK_OPT_FOOTNOTES) else { return nil }
    defer { cmark_parser_free(parser) }
    
    if let ext = cmark_find_syntax_extension("table") {
      cmark_parser_attach_syntax_extension(parser, ext)
    }
    
    if let ext = cmark_find_syntax_extension("autolink") {
      cmark_parser_attach_syntax_extension(parser, ext)
    }
    
    if let ext = cmark_find_syntax_extension("strikethrough") {
      cmark_parser_attach_syntax_extension(parser, ext)
    }
    
    if let ext = cmark_find_syntax_extension("tasklist") {
      cmark_parser_attach_syntax_extension(parser, ext)
    }
    
    cmark_parser_feed(parser, markdown, markdown.utf8.count)
    guard let node = cmark_parser_finish(parser) else { return nil }
    return String(cString: cmark_render_html(node, CMARK_OPT_HARDBREAKS | CMARK_OPT_UNSAFE, nil))
  }
  
  private let messageTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }()
  
  func renderMessage(message: Message) -> String {
    
    if let text = message.text, !text.isEmpty {
      let isLastMessage = message == messages.last
      
      let infoText: String = {
        if isLastMessage && agentStatus == .coldProcessing && overrideText.isEmpty {
          return "warming up..."
        } else {
          return messageTimestampFormatter.string(from: message.createdAt ?? Date())
        }
      }()
      
      var info: String {
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
        if message.modelName != nil, !message.modelName!.isEmpty {
          parts.append("Model: \(message.modelName!)")
        }
        return parts.joined(separator: "\n")
      }
      
      return """
      <div class="message-view">
        <svg class="avatar"><use href="#user-avatar"></use></svg>
        <div class="content">
          <div class="info-line">
            <span class="info-text">\(infoText)</span>
            <span class="mini-info">
              <button class="menu-button">
                <svg class="menu-icon"><use href="#circle-ellipsis"></use></svg>
              </button>
              \(info)
            </span>
          </div>
          <div class="message-text">
            \(self.renderMarkdownHTML(markdown: message.text ?? "")!)
          </div>
        </div>
      </div>
      """
    }
    return "<p>Pending...</p>"
  }
  
  
  init(messages: [Message], overrideText: String = "", agentStatus: Agent.Status?) {
    cmark_gfm_core_extensions_ensure_registered()
    self.messages = messages
    self.overrideText = overrideText
    self.agentStatus = agentStatus
  }
  
  func makeNSView(context: Context) -> WKWebView  {
    let userContentController = WKUserContentController()
    userContentController.add(context.coordinator, name: "displayMenu")
    
    let webViewConfiguration = WKWebViewConfiguration()
    webViewConfiguration.userContentController = userContentController
    
    let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
    webView.setValue(false, forKey: "drawsBackground")
    context.coordinator.webView = webView
    
    return webView
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, WKScriptMessageHandler {
    var parent: ConversationMessagesView
    var webView: WKWebView?
    
    init(_ parent: ConversationMessagesView) {
      self.parent = parent
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      if message.name == "displayMenu" {
        displayMenu(webView: webView!)
      }
    }
    
    func displayMenu(webView: WKWebView) {
      let menu = NSMenu()
      menu.addItem(NSMenuItem(title: "Option 1", action: #selector(optionSelected(_:)), keyEquivalent: ""))
      menu.addItem(NSMenuItem(title: "Option 2", action: #selector(optionSelected(_:)), keyEquivalent: ""))
      NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: webView)
    }
    
    @objc func optionSelected(_ sender: NSMenuItem) {
      // Handle menu selection
    }
  }
  
  func updateNSView(_ nsView: WKWebView, context: Context) {
    if let htmlPath = Bundle.main.path(forResource: "ConversationMessagesView", ofType: "html") {
      let url = URL(fileURLWithPath: htmlPath)
      do {
        let baseView = try String(contentsOf: url, encoding: .utf8)
        var messagesView = ""
        for message in messages {
          messagesView += renderMessage(message: message)
        }
        let html = baseView.replacingOccurrences(of: "%MESSAGES%", with: messagesView)
        
        nsView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
      } catch {
        print("Unable to load HTML content: \(error)")
      }
    }
  }
}
