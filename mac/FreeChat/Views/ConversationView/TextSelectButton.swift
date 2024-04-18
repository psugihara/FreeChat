import SwiftUI

struct TextSelectButton: View {
  @Binding var isTextSelectionEnabled: Bool
  
  var body: some View {
    Button(action: {
      isTextSelectionEnabled.toggle()
    }, label: {
      Image(systemName: "character.cursor.ibeam")
        .imageScale(.small)
        .help(isTextSelectionEnabled ? "Disable text selection" : "Enable text selection")
    })
    .buttonStyle(.plain)
    .foregroundColor(isTextSelectionEnabled ? .accentColor : .gray)
  }
}
