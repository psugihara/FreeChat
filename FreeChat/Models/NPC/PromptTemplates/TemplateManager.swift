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
  
  static let vicunaTemplate = VicunaTemplate()
  static let templates = EnumMap<TemplateFormat, Template> { format in
    switch format {
      case .chatML:
        return ChatMLTemplate()
      case .llama2:
        return Llama2Template()
      case .vicuna:
        return vicunaTemplate
      case .alpaca:
        return AlpacaTemplate()
    }
  }

  static func getTemplate(_ templateName: String?, modelName: String?) -> Template {
    if let format = try? formatWithDefault(templateName, modelName: modelName) {
      return templates[format]
    } else {
      return vicunaTemplate
    }
  }
  
  static func formatWithDefault(_ formatString: String?, modelName: String?) throws -> TemplateFormat {
    guard let formatString, !formatString.isEmpty else {
      // formatString not specified, determine format from model name
      return formatFromModel(modelName)
    }
    
    guard let format = TemplateFormat(rawValue: formatString) else {
      throw TemplateManagerError.unrecognizedFormat(formatString: formatString)
    }
    
    return format
  }
  
  static func formatFromModel(_ name: String?) -> TemplateFormat {
    guard let name, !name.isEmpty else {
      return .vicuna
    }
    
    if name.contains(/Mistral-7B-Instruct/.ignoresCase()) {
      return .llama2
    }
    
    print("formatFromModel", name)
    if name.contains(/nous-hermes-llama-?2/.ignoresCase()) {
      print("match")
      return .alpaca
    }

    if name.contains(/wizardlm/.ignoresCase()) {
      return .vicuna
    }
    
    if name.contains(/(code)?llama(2-|-2-)?-?(7B-|13B-|70B-)?instruct/.ignoresCase()) {
      return .llama2
    }
    
    if name.contains(/jackalope-7b/.ignoresCase()) {
      return .chatML
    }

    return .vicuna
  }
}
