//
//  MarkdownView.swift
//  FreeChat
//
//  Created by Bogdan Protsenko on 11/04/2024.
//

import SwiftUI
import WebKit
import libcmark_gfm

public class NoScrollWKWebView: WKWebView {
  public override func scrollWheel(with theEvent: NSEvent) {
    nextResponder?.scrollWheel(with: theEvent)
  }
}

extension WKWebView {
  func getContentHeight(completion: @escaping (CGFloat) -> Void) {
    let javascript = "document.querySelector('.content').getBoundingClientRect().height"
    self.evaluateJavaScript(javascript) { (result, error) in
      DispatchQueue.main.async {
        completion(result as? CGFloat ?? 0)
      }
    }
  }
  func updateContent(html: String) -> Void {
    self.evaluateJavaScript("document.querySelector('.content').innerHTML = '\(html)'")
  }
}

struct MarkdownRenderer: NSViewRepresentable {
  var markdownString: String
  
  @Binding var dynamicHeight: CGFloat
  
  func makeNSView(context: Context) -> WKWebView {
    cmark_gfm_core_extensions_ensure_registered()
    let webView = NoScrollWKWebView()
    webView.setValue(false, forKey: "drawsBackground")
    webView.navigationDelegate = context.coordinator
    webView.loadHTMLString(self.getFullHtml(), baseURL: nil)
    return webView
  }
  
  func getFullHtml() -> String {
    guard let htmlContent = renderMarkdownHTML(markdown: markdownString) else { return "" }
    let customStyle = """
        <style>
        body {
            overflow: hidden;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            color: #333;
        }
        .content {
            overflow: hidden;
        }
        @media (prefers-color-scheme: dark) {
            body {
                color: #CCC;
            }
        }
        </style>
        """
    return "<html><head>\(customStyle)</head><body><div class='content'>\(htmlContent)</div></body></html>"
  }
  
  func updateNSView(_ nsView: WKWebView, context: Context) {
    nsView.loadHTMLString(self.getFullHtml(), baseURL: nil)
  }
  
  class Coordinator: NSObject, WKNavigationDelegate {
    var parent: MarkdownRenderer
    
    init(parent: MarkdownRenderer) {
      self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      webView.getContentHeight { height in
        self.parent.dynamicHeight = height
      }
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
  
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
}

struct MarkdownView: View {
  @State private var dynamicHeight: CGFloat = .zero
  var markdownContent: String = ""
  
  var body: some View {
    MarkdownRenderer(markdownString: markdownContent, dynamicHeight: $dynamicHeight)
      .frame(height: dynamicHeight)
  }
}
