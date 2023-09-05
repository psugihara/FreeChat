//
//  QuickPromptButton.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/4/23.
//

import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
  @State var hovered = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(hovered ? .body.bold() : .body)
      .background(
        Capsule()
          .strokeBorder(Color.secondary, lineWidth: 1)
          .foregroundColor(Color.primary)
          .background(hovered ? Color.secondary.opacity(0.2) : Color.clear)
      )
      .clipShape(Capsule())
      .multilineTextAlignment(.leading) // Center-align multiline text
      .lineLimit(nil) // Allow unlimited lines
      .onHover(perform: { hovering in
        hovered = hovering
      })
      .animation(Animation.easeInOut(duration: 0.1), value: hovered)
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
      rest: "politely asking a colleague for a status update"
    ),
    QuickPrompt(
      title: "Outline an essay",
      rest: "about the French Revolution"
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
      rest: "know when a steak is done?"
    ),
    QuickPrompt(
      title: "Write a recipe",
      rest: "for the perfect martini"
    ),
    QuickPrompt(
      title: "Write a tweet",
      rest: "about what's going on today"
    ),
    QuickPrompt(
      title: "Write a joke",
      rest: "about an AI walking into a bar"
    ),
    QuickPrompt(
      title: "Write a 1-liner",
      rest: "to count lines of code in a directory, ignoring comments"
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
      .frame(maxWidth: .infinity, alignment: .leading)
    })
    .buttonStyle(CapsuleButtonStyle())
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
