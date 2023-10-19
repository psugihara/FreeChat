//
//  EnumMap.swift
//  FreeChat
//
//  Created by Peter Sugihara on 10/10/23.
//  Copied from https://www.swiftbysundell.com/articles/enum-iterations-in-swift-42/
//

import Foundation

struct EnumMap<Enum: CaseIterable & Hashable, Value> {
  private let values: [Enum : Value]
  
  init(resolver: (Enum) -> Value) {
    var values = [Enum : Value]()
    
    for key in Enum.allCases {
      values[key] = resolver(key)
    }
    
    self.values = values
  }
  
  subscript(key: Enum) -> Value {
    // Here we have to force-unwrap, since there's no way
    // of telling the compiler that a value will always exist
    // for any given key. However, since it's kept private
    // it should be fine - and we can always add tests to
    // make sure things stay safe.
    return values[key]!
  }
}
