//
//  EnvironmentValues.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/17/23.
//

import Foundation
import SwiftUI

private struct NewConversationKey: EnvironmentKey {
  static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
  var newConversation: () -> Void {
    get { self[NewConversationKey.self] }
    set { self[NewConversationKey.self] = newValue }
  }
}
