//
//  QuickPromptButton.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/4/23.
//

import SwiftUI

struct GrayBorderedCapsuleButtonStyle: PrimitiveButtonStyle {
  @State var hovered = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(hovered ? .body.bold() : .body)
      .background(
        Capsule()
          .strokeBorder(Color.secondary, lineWidth: 1)
          .foregroundColor(hovered ? Color.blue : Color.clear)
      )
      .multilineTextAlignment(.leading) // Center-align multiline text
      .lineLimit(nil) // Allow unlimited lines
      .onHover(perform: { hovering in
        hovered = hovering
        print("hover")
      })
  }
}

struct QuickPromptButton: View {
  struct QuickPrompt: Identifiable {
    let id = UUID()
    var title: String
    var rest: String
  }
  
  static let quickPrompts = [
    QuickPrompt(
      title: "Write an email",
      rest: "to a co-worker that includes the following points:\n"
    ),
    QuickPrompt(
      title: "Outline an essay",
      rest: "that will include these ideas:\n"
    ),
    QuickPrompt(
      title: "Design a DB schema",
      rest: "for an online store"
    ),
    QuickPrompt(
      title: "Write a SQL query",
      rest: "to count rows in my Users table"
    ),
    QuickPrompt(
      title: "How do you",
      rest: "know when a steak is done"
    ),
    QuickPrompt(
      title: "Provide a recipe",
      rest: "for the perfect martini"
    )
  ]
  
  @Binding var input: String
  var prompt: QuickPrompt
  
  var body: some View {
    Button(action: {
      print("clcik")
      input = prompt.title + " " + prompt.rest
    }, label: {
      VStack(alignment: .leading) {
        Text(prompt.title).bold().font(.caption2).lineLimit(1)
        Text(prompt.rest).font(.caption2).lineLimit(1).foregroundColor(.secondary)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
    })
    .buttonStyle(GrayBorderedCapsuleButtonStyle())
  }
}

struct QuickPromptButton_Previews_Container: View {
  var p: QuickPromptButton.QuickPrompt
  @State var input = ""
  var body: some View {
    QuickPromptButton(input: $input, prompt: p)
  }
}

struct QuickPromptButton_Previews: PreviewProvider {
  static var previews: some View {
    ForEach(QuickPromptButton.quickPrompts) { p in
      QuickPromptButton_Previews_Container(p: p)
        .previewDisplayName(p.title)
    }
  }
}
