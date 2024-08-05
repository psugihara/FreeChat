//
//  TestHierarchical.swift
//  FreeChat
//
//  Created by Sebastian Gray on 25/7/2024.
//

import SwiftUI

struct TestHierarchicalContentView: View {
    struct FileItem: Hashable, Identifiable, CustomStringConvertible {
        var id: Self { self }
        var name: String
        var children: [FileItem]? = nil
        var description: String {
            switch children {
            case nil:
                return "📄 \(name)"
            case .some(let children):
                return children.isEmpty ? "📂 \(name)" : "📁 \(name)"
            }
        }
    }
  @State private var selectedItems: Set<FileItem> = []
      let fileHierarchyData: [FileItem] = [
      FileItem(name: "users", children:
        [FileItem(name: "user1234", children:
          [FileItem(name: "Photos", children:
            [FileItem(name: "photo001.jpg"),
             FileItem(name: "photo002.jpg")]),
           FileItem(name: "Movies", children:
             [FileItem(name: "movie001.mp4")]),
              FileItem(name: "Documents", children: [])
          ]),
         FileItem(name: "newuser", children:
           [FileItem(name: "Documents", children: [])
           ])
        ]),
        FileItem(name: "private", children: nil)
    ]
  
  var body: some View {
          List(fileHierarchyData, children: \.children, selection: $selectedItems) { item in
              Text(item.description)
                  .foregroundColor(selectedItems.contains(item) ? .blue : .primary)
          }
      }
}


struct TestHierarchicalContentView_Previews: PreviewProvider {
    static var previews: some View {
        TestHierarchicalContentView()
    }
}
