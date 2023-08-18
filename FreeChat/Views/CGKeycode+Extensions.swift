//
//  CGKeycode+Extensions.swift
//  FreeChat
//
//  Created by Peter Sugihara on 8/18/23.
//

import CoreGraphics

extension CGKeyCode
{
  // Define whatever key codes you want to detect here
  static let kVK_Shift: CGKeyCode = 0x38

  var isPressed: Bool {
    CGEventSource.keyState(.combinedSessionState, key: self)
  }
}
