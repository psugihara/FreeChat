//
//  CopyButton.swift
//  FreeChat
//
//  Created by Peter Sugihara on 8/18/23.
//

import SwiftUI

struct CopyButton: View {
  var text: String
  var buttonText: String = ""
  private let pasteboard = NSPasteboard.general
  @State var justCopied = false
  
  var body: some View {
    Button {
      pasteboard.clearContents()
      pasteboard.setString(text, forType: .string)
      justCopied = true
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        justCopied = false
      }
    } label: {
      if buttonText.isEmpty {
        Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
          .padding(.vertical, 2)
      } else {
        Label(buttonText, systemImage: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
          .padding(.vertical, 2)
      }
    }
    .frame(alignment: .center)
  }
}

struct CopyButton_Previews: PreviewProvider {
  static var previews: some View {
    CopyButton(text: "text to copy")
  }
}
