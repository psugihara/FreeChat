//
//  PromptTemplateTests.swift
//  FreeChatTests
//
//  Created by Peter Sugihara on 10/6/23.
//

import XCTest
@testable import FreeChat

final class PromptTemplateTests: XCTestCase {
  var shortConvo: [String] = [
    "Hey baby!",
    "Wassup, user?",
    "n2m hbu"
  ]
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testLlama2Opening() throws {
    let p = Llama2Template().run(systemPrompt: "A system prompt", messages: ["sup"])
    let expected = """
    <s>[INST] <<SYS>>
    A system prompt
    <</SYS>>
    
    sup [/INST] \
    
    """
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }
  
  func testLlama2ShortConvo() throws {
    let p = Llama2Template().run(systemPrompt: "A system prompt", messages: shortConvo)
    let expected = """
    <s>[INST] <<SYS>>
    A system prompt
    <</SYS>>
    
    Hey baby! [/INST] Wassup, user? </s><s>[INST] n2m hbu [/INST] 
    """
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }

  func testVicunaOpening() throws {
    let expected = """
    SYSTEM: A system prompt
    USER: hi
    ASSISTANT: \

    """
    let p = VicunaTemplate().run(systemPrompt: "A system prompt", messages: ["hi"])
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }
  
  func testVicunaShortConvo() throws {
    let expected = """
    SYSTEM: A system prompt
    USER: Hey baby!
    ASSISTANT: Wassup, user?
    USER: n2m hbu
    ASSISTANT: \

    """
    let p = VicunaTemplate().run(systemPrompt: "A system prompt", messages: shortConvo)
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }
  
  func testChatMLOpening() throws {
    let expected = """
    <|im_start|>system
    A system prompt
    <|im_end|>
    <|im_start|>user
    hi
    <|im_end|>
    <|im_start|>assistant

    """
    let p = ChatMLTemplate().run(systemPrompt: "A system prompt", messages: ["hi"])
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }
  
  func testChatMLShortConvo() throws {
    let expected = """
    <|im_start|>system
    A system prompt
    <|im_end|>
    <|im_start|>user
    Hey baby!
    <|im_end|>
    <|im_start|>assistant
    Wassup, user?
    <|im_end|>
    <|im_start|>user
    n2m hbu
    <|im_end|>
    <|im_start|>assistant

    """
    let p = ChatMLTemplate().run(systemPrompt: "A system prompt", messages: shortConvo)
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }

  func testAlpacaOpening() throws {
    let expected = """
    ### Instruction:
    A system prompt

    Conversation so far:
    user: hi
    you:

    Respond to user's last line with markdown.

    ### Response:

    """
    let p = AlpacaTemplate().run(systemPrompt: "A system prompt", messages: ["hi"])

    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }

  func testAlpacaShortConvo() throws {
    let expected = """
    ### Instruction:
    A system prompt

    Conversation so far:
    user: Hey baby!
    you: Wassup, user?
    user: n2m hbu
    you:

    Respond to user's last line with markdown.

    ### Response:

    """
    let p = AlpacaTemplate().run(systemPrompt: "A system prompt", messages: shortConvo)

    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }

  func testTemplatesHaveMatchingFormats() throws {
    for format in TemplateFormat.allCases {
      let template = TemplateManager.templates[format]
      XCTAssertEqual(template.format, format)
    }
  }
}
