//
//  Template.swift
//  FreeChat
//
//  Created by Peter Sugihara on 10/7/23.
//

import Foundation

protocol Template {
  static var stopWords: [String] { get }
  func run(systemPrompt: String, messages: [String]) -> String
}

struct Llama2Template: Template {
  static var stopWords: [String] = ["</s>"]
  
  func run(systemPrompt: String, messages: [String]) -> String {
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
          p += "<s>[INST] \(message) [/INST] "
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
        p += "\(message) </s>"
      }
      
      userTalking.toggle()
    }
    
    return p
  }
}

struct ContinuationTemplate: Template {
  static var stopWords: [String] = ["\nUser:", "\nUSER:", "\nuser"]
  
  func run(systemPrompt: String, messages: [String]) -> String {
    var p = """
      \(systemPrompt)
      A conversation between User and you, Assistant.
      """
    
    var userTalking = true
    for message in messages {
      if userTalking {
        p.append("\nUser: \(message)")
      } else {
        p.append("\nAssistant: \(message)")
      }
      
      userTalking.toggle()
    }
    
    return p
  }
}

struct VicunaTemplate: Template {
  static var stopWords: [String] = ["USER:"]
  
  func run(systemPrompt: String, messages: [String]) -> String {
    var p = "\(systemPrompt)"
    
    var userTalking = true
    for message in messages {
      if userTalking {
        p.append(" USER: \(message)")
      } else {
        p.append(" ASSISTANT: \(message)")
      }
      userTalking.toggle()
    }
    
    if !userTalking {
      p.append(" ASSISTANT:")
    }
    
    return p
  }
}

struct ChatMLTemplate: Template {
  static var stopWords: [String] = ["<|im_end|>"]
  
  func run(systemPrompt: String, messages: [String]) -> String {
    var p = """
    <|im_start|>system
    \(systemPrompt)<|im_end|>
    """
    
    var userTalking = true
    for message in messages {
      p.append("""
          <|im_start|>\(userTalking ? "user" : "assistant")
          \(message)<|im_end|>
          """)
      userTalking.toggle()
    }
    
    return p
  }
}
