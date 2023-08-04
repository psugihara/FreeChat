////
////  File.swift
////  
////
////  Created by Peter Sugihara on 7/30/23.
////
//
//import Foundation
//
//actor Conversation {
//  enum Status {
//    case started
//    case stopped
//  }
//  
//  var status = Status.stopped
//  var agents: [Agent] = []
//  var messages: [Message] = []
//  
//  init(agents: [Agent], messages: [Message]) {
//    self.agents = agents
//    self.messages = messages
//  }
//  
//  func start() {
//    status = .started
//    while (status == .started) {
//      // find last agent to speak
//      // get index in agents
//      // increment one more than index
//    }
//  }
//  
//  func stop() {
//    status = .stopped
//  }
//      
//  
//}
