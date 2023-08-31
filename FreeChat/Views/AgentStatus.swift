//
//  AgentStatus.swift
//  FreeChat
//
//  Created by Peter Sugihara on 8/30/23.
//

import SwiftUI

struct AgentStatus: View {
  @ObservedObject var agent: Agent
  
  var body: some View {
    HStack {
      ZStack(alignment: .bottomTrailing) {
        Image("LlamaAvatar")
          .resizable()
          .frame(width: 24, height: 24)
        ZStack {
          Circle()
            .fill(.white)
            .frame(width: 10, height: 10)
          if agent.status == .cold {
            Circle()
              .fill(.orange)
              .frame(width: 8, height: 8)
          } else {
            Circle()
              .fill(.green)
              .frame(width: 8, height: 8)
          }
        }
      }
    }
  }
}

struct AgentStatus_PreviewsContainer: View {
  @State var agent = Agent(id: "llama", prompt: "", systemPrompt: "", modelPath: "")

  var body: some View {
    AgentStatus(agent: agent)
  }
}

struct AgentStatus_Previews: PreviewProvider {
  static var previews: some View {
    AgentStatus_PreviewsContainer()
  }
}
