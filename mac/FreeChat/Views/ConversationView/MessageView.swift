//
//  MessageView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/4/23.
//

import SwiftUI
import MarkdownUI
import Splash


struct MessageView: View {
  @Environment(\.colorScheme) private var colorScheme

  @ObservedObject var m: Message
  let overrideText: String // for streaming replies
  let agentStatus: Agent.Status?

  @State var showInfoPopover = false
  @State var isHover = false
  @State var animateDots = false

  init(_ m: Message, overrideText: String = "", agentStatus: Agent.Status?) {
    self.m = m
    self.overrideText = overrideText
    self.agentStatus = agentStatus
  }

  var messageText: String {
    (overrideText.isEmpty && m.text != nil ? m.text! : overrideText)
    // make newlines display https://github.com/gonzalezreal/swift-markdown-ui/issues/92
    .replacingOccurrences(of: "\n", with: "  \n", options: .regularExpression)
  }

  var infoText: some View {

    (agentStatus == .coldProcessing && overrideText.isEmpty
      ? Text("warming up...")
    : Text(m.createdAt ?? Date(), formatter: messageTimestampFormatter))
      .font(.caption)
  }

  var info: String {
    var parts: [String] = []
    if m.responseStartSeconds > 0 {
      parts.append("Response started in: \(String(format: "%.3f", m.responseStartSeconds)) seconds")
    }
    if m.predictedPerSecond > 0 {
      parts.append("Tokens generated per second: \(String(format: "%.3f", m.predictedPerSecond))")
    }
    if m.modelName != nil, !m.modelName!.isEmpty {
      parts.append("Model: \(m.modelName!)")
    }
    return parts.joined(separator: "\n")
  }

  var menuContent: some View {
    Group {
      if m.responseStartSeconds > 0 {
        Button("Show info") {
          self.showInfoPopover.toggle()
        }
      }
      if overrideText == "", m.text != nil, !m.text!.isEmpty {
        CopyButton(text: m.text!, buttonText: "Copy to clipboard")
      }
    }
  }

  var infoLine: some View {
    let showButtons = (isHover && overrideText.isEmpty && agentStatus != .processing && agentStatus != .coldProcessing)

    return HStack(alignment: .center, spacing: 4) {
      infoText
      Menu(content: {
        menuContent
      }, label: {
        Group {
          Image(systemName: "ellipsis.circle").imageScale(.medium)
            .background(.clear)
        }
          .imageScale(.small)
          .frame(minHeight: 16, maxHeight: .infinity)
          .padding(.leading, 3)
          .padding(.trailing, 3) /* expand click area */
          .padding(.vertical, 2)
          .background(.primary.opacity(0.00001)) // needed to be clickable
      })
        .offset(y: -1)
        .menuStyle(.circle)
        .popover(isPresented: $showInfoPopover) {
        Text(info).padding(12).font(.caption).textSelection(.enabled)
      }
        .opacity(showButtons ? 1 : 0)
        .disabled(!overrideText.isEmpty)
      if m.fromId != Message.USER_SPEAKER_ID {
        if m.feedbackId == FeedbackButton.PENDING_FEEDBACK_ID {
          ProgressView().controlSize(.mini)
        } else {
          FeedbackButton(message: m, thumbs: .up)
            .opacity(showButtons ? 1 : 0)
            .padding(.trailing, 3)
          if m.feedbackId == nil {
            FeedbackButton(message: m, thumbs: .down)
              .opacity(showButtons ? 1 : 0)
          }
        }
      }
    }.foregroundColor(.gray)
      .fixedSize(horizontal: false, vertical: true)
  }

  var body: some View {
    HStack(alignment: .top) {
      ZStack(alignment: .bottomTrailing) {
        Image(m.fromId == Message.USER_SPEAKER_ID ? "UserAvatar" : "LlamaAvatar")
          .shadow(color: .secondary.opacity(0.3), radius: 2, x: 0, y: 0.5)
        if agentStatus == .coldProcessing || agentStatus == .processing {
          ZStack {
            Circle()
              .fill(.background)
              .overlay(Circle().stroke(.gray.opacity(0.2), lineWidth: 0.5))

            Group {
              Text("•")
                .opacity(animateDots ? 1 : 0)
                .offset(x: 0)
              Text("•")
                .offset(x: 4)
                .opacity(animateDots ? 1 : 0.5)
                .opacity(animateDots ? 1 : 0)
              Text("•")
                .offset(x: 8)
                .opacity(animateDots ? 1 : 0)
                .opacity(animateDots ? 1 : 0)
            }.animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateDots)
              .offset(x: -4, y: -0.5)
              .font(.caption)

          }.frame(width: 14, height: 14)
            .task {
            animateDots.toggle()
            animateDots = true
          }
            .onDisappear {
            animateDots = false
          }
            .transition(.opacity)
        }
      }
        .padding(2)
        .padding(.top, 1)

      VStack(alignment: .leading, spacing: 1) {
        infoLine
        Markdown(messageText)
          .markdownTheme(.freeChat)
          .markdownCodeSyntaxHighlighter(.splash(theme: self.theme))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .transition(.identity)
      }
        .padding(.top, 3)
        .padding(.bottom, 8)
        .padding(.horizontal, 3)
    }
      .padding(.vertical, 3)
      .padding(.horizontal, 8)
      .background(Color(white: 1, opacity: 0.000001)) // makes contextMenu work
    .animation(Animation.easeOut, value: isHover)
      .contextMenu {
      menuContent
    }
      .onHover { hovered in
      isHover = hovered
    }
  }

  private var theme: Splash.Theme {
    // NOTE: We are ignoring the Splash theme font
    switch self.colorScheme {
    case ColorScheme.dark:
      return .wwdc17(withFont: .init(size: 16))
    default:
      return .sunset(withFont: .init(size: 16))
    }
  }
}

private let messageTimestampFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short
  return formatter
}()

struct MessageView_Previews: PreviewProvider {
  static var messages: [Message] {
    let ctx = PersistenceController.preview.container.viewContext
    let c = try! Conversation.create(ctx: ctx)
    let m = try! Message.create(
      text: "hello there, I'm well! How are **you**?",
      fromId: "User",
      conversation: c,
      systemPrompt: "you are a system prompt",
      inContext: ctx
    )
    let m2 = try! Message.create(
      text: "Doing pretty well, can you write me some code?",
      fromId: Message.USER_SPEAKER_ID,
      conversation: c,
      systemPrompt: "you are a system prompt",
      inContext: ctx
    )
    let m3 = Message(context: ctx)
    m3.conversation = c
    m3.fromId = "llama"
    m3.text = """
      Hi! You can use `FileManager` to get information about files, including their sizes. Here's an example of getting the size of a text file:
      ```swift
      let path = "path/to/file"
      do {
          let attributes = try FileManager.default.attributesOfItem(atPath: path)
          if let fileSize = attributes[FileAttributeKey.size] as? UInt64 {
              print("The file is \\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))")
          }
      } catch {
          // Handle any errors
      }
      ```
      """
    return [m, m2, m3]
  }

  static var previews: some View {
    List(MessageView_Previews.messages) {
      MessageView($0, agentStatus: .processing)
    }.environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
