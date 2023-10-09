//
//  PromptTemplate.swift
//  FreeChat
//
//  Created by Peter Sugihara on 10/6/23.
//

import Foundation

struct TemplateManager {
  enum TemplateManagerError: Error {
    case unrecognizedFormat(formatString: String)
  }
  enum Format: String {
    case llama2, chatML, alpaca, vicuna
  }
  
  //
  static func getTemplate(_ templateName: String?, modelName: String?) -> Template {
    switch try? formatWithDefault(templateName, modelName: modelName) {
      case .llama2:
        Llama2Template()
      case .chatML:
        ChatMLTemplate()
        //      case .userAssistant:
        //        runUserAssistant()
//      case .alpaca:
      default:
        Llama2Template()
    }
  }
  
  static func formatWithDefault(_ formatString: String?, modelName: String?) throws -> Format {
    guard let formatString, !formatString.isEmpty else {
      // formatString not specified, determine format from model name
      return formatFromModel(modelName)
    }
    
    guard let format = Format(rawValue: formatString) else {
      throw TemplateManagerError.unrecognizedFormat(formatString: formatString)
    }
    return format
  }
  
  static func formatFromModel(_ name: String?) -> Format {
    guard let name, !name.isEmpty else {
      return .vicuna
    }
    
    if name.contains(/Mistral-7B-Instruct/.ignoresCase()) {
      return .llama2
    }
    
    if name.contains(/nous-hermes-llama2/.ignoresCase()) {
      return .alpaca
    }

    if name.contains(/wizardlm/.ignoresCase()) {
      return .vicuna
    }

    return .vicuna
  }
}
