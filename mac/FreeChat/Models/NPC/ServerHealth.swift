//
//  ServerHealth.swift
//  FreeChat
//

import Foundation

fileprivate struct ServerHealthRequest {

  enum ServerHealthError: Error {
    case invalidResponse
  }

  func checkOK(url: URL) async throws -> Bool {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 1
    let (data, response) = try await URLSession(configuration: config).data(from: url)
    guard let responseCode = (response as? HTTPURLResponse)?.statusCode,
          responseCode > 0
    else { throw ServerHealthError.invalidResponse }

    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
          let jsonStatus: String = json["status"]
    else { throw ServerHealthError.invalidResponse }

    return responseCode == 200 && jsonStatus == "ok"
  }
}

@globalActor
actor ServerHealth {

  static let shared = ServerHealth()

  private var url: URL?
  private var healthRequest = ServerHealthRequest()
  private var bucket: [Double?] = Array(repeating: nil, count: 15) // last responses
  private var bucketIndex = 0
  private let thresholdMilli = 0.3 // with serialization
  private var bucketValues: [Double] { bucket.compactMap({ $0 }) }
  var score: Double {
    bucketValues.reduce(0, +) / Double(bucketValues.count)
  }

  func updateURL(_ newURL: URL?) {
    self.url = newURL
    self.bucket.removeAll(keepingCapacity: true)
    self.bucket = Array(repeating: nil, count: 15)
  }

  func check() async {
    guard let url = self.url else { return }
    let startTime = CFAbsoluteTimeGetCurrent()
    do {
      let resOK = try await healthRequest.checkOK(url: url)
      let delta = CFAbsoluteTimeGetCurrent() - startTime
      let deltaV = (1 - (delta - thresholdMilli) / thresholdMilli)
      let deltaW = (deltaV > 1 ? 1 : deltaV) * 0.25
      let resW = (resOK ? 1 : 0) * 0.75
      putScore(resW + deltaW)
    } catch {
      print("error requesting url \(url.absoluteString): ", error)
      putScore(0)
    }
  }

  private func putScore(_ newScore: Double) {
    bucket[bucketIndex] = newScore
    bucketIndex = (bucketIndex + 1) % bucket.count
  }
}
