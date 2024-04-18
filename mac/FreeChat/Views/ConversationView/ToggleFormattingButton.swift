import SwiftUI

struct ToggleFormattingButton: View {
  @Binding var active: Bool
  
  var body: some View {
    Button(action: {
      active.toggle()
    }, label: {
      Image(systemName: "character.cursor.ibeam")
        .imageScale(.small)
        .help(active ? "Disable formatting" : "Enable formatting")
    })
    .buttonStyle(.plain)
    .foregroundColor(active ? .accentColor : .gray)
  }
}
