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

    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let jsonStatus: String = json["status"] as? String
    else { throw ServerHealthError.invalidResponse }

    return responseCode == 200 && jsonStatus == "ok"
  }
}

fileprivate struct ServerHealthResponse {
  let ok: Bool
  let ms: Double?
  let score: Double
}

@globalActor
actor ServerHealth {

  static let shared = ServerHealth()

  private var url: URL?
  private var healthRequest = ServerHealthRequest()
  private var bucket: [ServerHealthResponse?] = Array(repeating: nil, count: 10) // last responses
  private var bucketIndex = 0
  private let thresholdSeconds = 0.3
  private var bucketScores: [Double] { bucket.compactMap({ $0?.score }).reversed() }
  private var bucketMillis: [Double] { bucket.compactMap({ $0?.ms }) }
  var score: Double { bucketScores.reduce(0, +) / Double(bucketScores.count) }
  var responseMilli: Double { bucketMillis.reduce(0, +) / Double(bucketMillis.count) }

  func updateURL(_ newURL: URL?) {
    self.url = newURL
    self.bucket.removeAll(keepingCapacity: true)
    self.bucket = Array(repeating: nil, count: 10)
  }

  func check() async {
    guard let url = self.url else { return }
    let startTime = CFAbsoluteTimeGetCurrent()
    do {
      let resOK = try await healthRequest.checkOK(url: url)
      let delta = CFAbsoluteTimeGetCurrent() - startTime
      let deltaV = (1 - (delta - thresholdSeconds) / thresholdSeconds)
      let deltaW = (deltaV > 1 ? 1 : deltaV) * 0.25
      let resW = (resOK ? 1 : 0) * 0.75
      putResponse(ServerHealthResponse(ok: resOK, ms: delta, score: resW + deltaW))
    } catch {
      print("error requesting url \(url.absoluteString): ", error)
      putResponse(ServerHealthResponse(ok: false, ms: nil, score: 0))
    }
  }

  private func putResponse(_ newObservation: ServerHealthResponse) {
    bucket[bucketIndex] = newObservation
    bucketIndex = (bucketIndex + 1) % bucket.count
  }
}
