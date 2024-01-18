//
//  CalcState.swift
//  FreeChat
//
//  Created by Peter Sugihara on 1/15/24.
//

import Foundation
import SwiftUI

class CalcState: ObservableObject {  
  @Published var userText: String = "" // raw user text in the UI
  @Published var output: String = ""
  @Published var outputPending = false
  @Published var lines: [String: String] = [:] // line from usertext paired with response

  func linesTexts() -> [String] {
    return userText.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
  }

  func calculateOutput() {
    var result = ""

    var nextOutputPending = false
    for lineText in userText.components(separatedBy: "\n") {
      let key = lineText.trimmingCharacters(in: .whitespaces)
      if let response = lines[key] {
        result += response
      } else if !key.isEmpty {
        nextOutputPending = true
      }
      result += "\n"
    }

    withAnimation {
      outputPending = nextOutputPending
      output = result
    }
  }

  func addLine(key: String, response: String) {
    lines[key] = response.components(separatedBy: .newlines).first
    calculateOutput()
  }
}

struct Line {
  var prompt: String
  var response: String
}
