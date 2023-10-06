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
    "n2m hbu",
    ";)"
  ]
  var longConvo: [String] = [
    
  ]
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testRunLlama2Blank() throws {
    let p = PromptTemplate(systemPrompt: "A system prompt", messages: []).run(.llama2)
    let expected = """
    <s>[INST] <<SYS>>
    A system prompt
    <</SYS>>
    
    hi [/INST]
    """
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }
  
  func testRunLlama2ShortConvo() throws {
    let p = PromptTemplate(systemPrompt: "A system prompt", messages: shortConvo).run(.llama2)
    let expected = """
    <s>[INST] <<SYS>>
    A system prompt
    <</SYS>>
    
    Hey baby! [/INST] Wassup, user? </s><s>[INST] n2m hbu [/INST] ;) </s>
    """
    
    XCTAssert(!p.isEmpty)
    XCTAssertEqual(p, expected)
  }
}
