//
//  Network.swift
//  FreeChat
//
//  Created by Peter Sugihara on 11/27/23.
//

import Foundation
import Network

final class Network: ObservableObject {
  static let shared = Network()

  @Published private(set) var isConnected = false
  @Published private(set) var isCellular = false

  private let nwMonitor = NWPathMonitor()
  private let workerQueue = DispatchQueue.global()

  init() {
    start()
  }

  public func start() {
    nwMonitor.start(queue: workerQueue)
    nwMonitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        self?.isConnected = path.status == .satisfied
        self?.isCellular = path.usesInterfaceType(.cellular)
      }
    }
  }

  public func stop() {
    nwMonitor.cancel()
  }
}
