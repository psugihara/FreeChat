//
//  UISettingsView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 12/9/23.
//

import SwiftUI
import KeyboardShortcuts

struct UISettingsView: View {
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: true)],
    animation: .default)
  private var models: FetchedResults<Model>

  @AppStorage("playSoundEffects") private var playSoundEffects = true
  @AppStorage("showFeedbackButtons") private var showFeedbackButtons = true

  var globalHotkey: some View {
    KeyboardShortcuts.Recorder("Summon chat", name: .summonFreeChat)
  }

  var soundEffects: some View {
    Toggle("Play sound effects", isOn: $playSoundEffects)
  }

  var feedbackButtons: some View {
    VStack(alignment: .leading) {
      Toggle("Show feedback buttons", isOn: $showFeedbackButtons)

      Text("The thumb feedback buttons allow you to contribute conversations to an open dataset to help train future models.")
        .font(.callout)
        .foregroundColor(Color(NSColor.secondaryLabelColor))
        .lineLimit(5)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  var body: some View {
    Form {
      globalHotkey
      soundEffects
      feedbackButtons
    }
      .formStyle(.grouped)
      .frame(minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400, alignment: .center)
  }
}

#Preview {
  UISettingsView()
}
