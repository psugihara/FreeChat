//
//  SettingsView.swift
//  Chats
//
//  Created by Peter Sugihara on 8/6/23.
//

import SwiftUI

struct SettingsView: View {
  static let title = "Settings"

  private enum Tabs: Hashable {
    case ai, ui
  }

  var body: some View {
    TabView {
      UISettingsView()
        .tabItem {
          Label("General", systemImage: "gear")
        }
        .tag(Tabs.ui)
      AISettingsView()
        .tabItem {
          Label("Intelligence", systemImage: "hands.and.sparkles.fill")
        }
        .tag(Tabs.ai)
    }
      .frame(minWidth: 300, maxWidth: 600, minHeight: 184, idealHeight: 195, maxHeight: 400, alignment: .center)
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
