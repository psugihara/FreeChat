//
//  DownloadManager.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/28/23.
//

import Foundation
import OSLog
import CoreData
import SwiftUI

class DownloadManager: NSObject, ObservableObject {
  static var shared = DownloadManager()

  @AppStorage("selectedModelId") private var selectedModelId: String = Model.unsetModelId

  var viewContext: NSManagedObjectContext?

  private var urlSession: URLSession!
  @Published var tasks: [URLSessionTask] = []
//  @Published var tasksInProgress = 0
  @Published var lastUpdatedAt = Date()
  
  override private init() {
    super.init()

    let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background2")
    config.isDiscretionary = false
    
    // Warning: Make sure that the URLSession is created only once (if an URLSession still
    // exists from a previous download, it doesn't create a new URLSession object but returns
    // the existing one with the old delegate object attached)
    urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    
    updateTasks()
  }
  
  func startDownload(url: URL) {
    print("starting download", url)
    // ignore download if it's already in progress
    if tasks.contains(where: { $0.originalRequest?.url == url }) { return }
    let task = urlSession.downloadTask(with: url)
    tasks.append(task)
    task.resume()
  }
  
  private func updateTasks() {
    urlSession.getAllTasks { tasks in
      DispatchQueue.main.async {
        self.tasks = tasks
        self.lastUpdatedAt = Date()
      }
    }
  }
}

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
  func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten _: Int64, totalBytesExpectedToWrite _: Int64) {
    DispatchQueue.main.async {
      let now = Date()
      if self.lastUpdatedAt.timeIntervalSince(now) > 10 {
        self.lastUpdatedAt = now
      }
    }
  }
  
  func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    os_log("Download finished: %@ %@", type: .info, location.absoluteString, downloadTask.originalRequest?.url?.lastPathComponent ?? "")
    // The file at location is temporary and will be gone afterwards
    
    // move file to app resources
    let fileName = downloadTask.originalRequest?.url?.lastPathComponent ?? "default.gguf"
    let folderName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "FreeChat"
    let destDir = URL.applicationSupportDirectory.appending(path: folderName, directoryHint: .isDirectory)
    let destinationURL = destDir.appending(path: fileName)
    
    let fileManager = FileManager.default
    try? fileManager.removeItem(at: destinationURL)

    do {
      let folderExists = (try? destDir.checkResourceIsReachable()) ?? false
      if !folderExists {
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: false)
      }
      try fileManager.moveItem(at: location, to: destinationURL)
    } catch {
      os_log("FileManager copy error at %@ to %@ error: %@", type: .error, location.absoluteString, destinationURL.absoluteString, error.localizedDescription)
      return
    }
    
    // create Model that points to file
    os_log("DownloadManager creating model", type: .info)
    DispatchQueue.main.async { [self] in
      let ctx = viewContext ?? PersistenceController.shared.container.viewContext
      do {
        let m = try Model.create(context: ctx, fileURL: destinationURL)
        os_log("DownloadManager created model %@", type: .info, m.id?.uuidString ?? "missing id")
        selectedModelId = m.id?.uuidString ?? Model.unsetModelId
      } catch {
        os_log("Error creating model on main thread: %@", type: .error, error.localizedDescription)
      }
      lastUpdatedAt = Date()
    }
  }
  
  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error {
      os_log("Download error: %@", type: .error, String(describing: error))
    } else {
      os_log("Task finished: %@", type: .info, task)
    }
    
    let taskId = task.taskIdentifier
    DispatchQueue.main.async {
      self.tasks.removeAll(where: { $0.taskIdentifier == taskId })
    }
  }
}
