//
//  String+TrimQuotes.swift
//  FreeChat
//

import Foundation

extension String {
  func trimTrailingQuote() -> String {
    guard self.last == "\"" else { return self }

    // Count the number of quotes in the string
    let countOfQuotes = self.filter({ $0 == "\"" }).count
    guard countOfQuotes % 2 != 0 else { return self }
    var outputString = self
    // If there is an odd number of quotes, remove the last one
    if let indexOfLastQuote = self.lastIndex(of: "\"") {
      outputString.remove(at: indexOfLastQuote)
    }

    return outputString
  }
}
