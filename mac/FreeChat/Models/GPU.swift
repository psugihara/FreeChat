//
//  GPU.swift
//  FreeChat
//
//  Created by Peter Sugihara on 12/16/23.
//

import Foundation

final class GPU: ObservableObject {
  static let shared = GPU()

  @Published private(set) var available = false

  init() {
    // llama crashes on intel macs when gpu-layers != 0, not sure why
    available = getMachineHardwareName() == "arm64"
  }

  private func getMachineHardwareName() -> String? {
    var sysInfo = utsname()
    let retVal = uname(&sysInfo)
    var finalString: String? = nil

    if retVal == EXIT_SUCCESS {
      let bytes = Data(bytes: &sysInfo.machine, count: Int(_SYS_NAMELEN))
      finalString = String(data: bytes, encoding: .utf8)
    }

    // _SYS_NAMELEN will include a billion null-terminators. Clear those out so string comparisons work as you expect.
    return finalString?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
  }
}
