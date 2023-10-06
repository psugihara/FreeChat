//
//  PromptTemplate.swift
//  FreeChat
//
//  Created by Peter Sugihara on 10/6/23.
//

import Foundation

struct PromptTemplate {
  enum Format: String {
    case continuation, llama2, chatML, userAssistant, alpaca
  }
  
  var systemPrompt: String
  var messages: [String]
  
  func run(_ format: Format) -> String {
    switch format {
      case .continuation:
        runContinuation()
      case .llama2:
        runLlama2()
      case .chatML:
        runChatML()
      case .userAssistant:
        runUserAssistant()
      case .alpaca:
        runAlpaca()
    }
  }
  
  private func runContinuation() -> String {
    ""
  }
  
  private func runLlama2() -> String {
    var p = """
      <s>[INST] <<SYS>>
      \(systemPrompt)
      <</SYS>>
      
      \(messages.first ?? "hi") [/INST]
      """
    
    var userTalking = false
    for message in messages.dropFirst() {
      if userTalking {
        if p.suffix(2000).contains(systemPrompt) {
          p += "<s>[INST] \(message) [/INST]"
        } else {
          // if the system prompt hasn't been covered in a while, pepper it in
          p += """
            <s>[INST] <<SYS>>
            \(systemPrompt)
            <<SYS>>

            \(message) [/INST]
            """
        }
      } else {
        p += " \(message) </s>"
      }
      
      userTalking.toggle()
    }
    
    return p
  }
  
  private func runChatML() -> String {
    ""
  }
  
  private func runUserAssistant() -> String {
    ""
  }
  
  private func runAlpaca() -> String {
    ""
  }
}
