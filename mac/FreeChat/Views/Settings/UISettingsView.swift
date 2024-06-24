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
  @AppStorage("fontSizeOption") private var fontSizeOption: Double = 12
  
    
    
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

  var fontSizeOptions: some View {
      HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, content: {
          Text("Font size: \(String(format: "%.0f", fontSizeOption))")
               
          Slider(value: $fontSizeOption, in: 10...30, step: 1)
                     .padding()
      })
  }
    
  var body: some View {
    Form {
      globalHotkey
      soundEffects
      feedbackButtons
      fontSizeOptions
    }
      .formStyle(.grouped)
      .frame(minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400, alignment: .center)
  }
}

#Preview {
  UISettingsView()
}
