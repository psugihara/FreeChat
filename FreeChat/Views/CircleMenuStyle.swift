//
//  CircleButtonStyle.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/20/23.
//

import Foundation
import SwiftUI

struct CircleMenuStyle: MenuStyle {
  @State var hovered = false
  func makeBody(configuration: Configuration) -> some View {
    Menu(configuration)
      .menuStyle(.button)
      .buttonStyle(.plain)
      .padding(1)
      .foregroundColor(hovered ? .primary : .gray)
      .onHover(perform: { hovering in
        hovered = hovering
      })
      .animation(Animation.easeInOut(duration: 0.1), value: hovered)
  }
}

extension MenuStyle where Self == CircleMenuStyle {
  static var circle: CircleMenuStyle { CircleMenuStyle() }
}
