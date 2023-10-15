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
      // vicuna is a decent default because it's simple
      return .vicuna
    }
    
    // This is terrible and I would love a better way to do it.

    if name.contains(/(codellama|llama)(2-|-2-)?-?(\d{1,2}B-)?instruct/.ignoresCase()) || name.contains(/Mistral-7B-Instruct/.ignoresCase()) {
      return .llama2
    }

    if name.contains(/Mistral-7B-OpenOrca/.ignoresCase()) ||
        name.contains(/dolphin-2.1-mistral-7B/.ignoresCase()) ||
        name.contains(/samantha-1.2-mistral-7B/.ignoresCase()) ||
        name.contains(/jackalope-7b/.ignoresCase()) {
      return .chatML
    }

    if name.contains(/nous-hermes-llama-?2/.ignoresCase()) {
      return .alpaca
    }
    
    return .vicuna
  }

  static func formatTitle(_ format: TemplateFormat) -> String {
    switch format {
      case .alpaca:
        "Alpaca"
      case .chatML:
        "ChatML"
      case .llama2:
        "Llama 2"
      case .vicuna:
        "Vicuna"
    }
  }
}
