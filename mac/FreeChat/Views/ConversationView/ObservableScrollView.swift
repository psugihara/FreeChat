//
//  ObservableScrollView.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/14/23.
//  adapted from https://swiftuirecipes.com/blog/swiftui-scrollview-scroll-offset
//

import SwiftUI

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
  static var defaultValue = CGFloat.zero
  
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value += nextValue()
  }
}

struct ScrollViewHeightPreferenceKey: PreferenceKey {
  static var defaultValue = CGFloat.zero
  
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value += nextValue()
  }
}

// A ScrollView wrapper that tracks scroll offset changes.
struct ObservableScrollView<Content>: View where Content : View {
  @Namespace var scrollSpace
  
  @Binding var scrollOffset: CGFloat
  @Binding var scrollHeight: CGFloat
  let content: (ScrollViewProxy) -> Content
  
  init(scrollOffset: Binding<CGFloat>,
       scrollHeight: Binding<CGFloat>,
       @ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
    _scrollOffset = scrollOffset
    _scrollHeight = scrollHeight
    self.content = content
  }
  
  var body: some View {
    ScrollView {
      ScrollViewReader { proxy in
        content(proxy)
          .background(GeometryReader { geo in
            let offset = -geo.frame(in: .named(scrollSpace)).minY
            let height = geo.size.height
            Color
              .clear
              .preference(key: ScrollViewOffsetPreferenceKey.self,
                          value: offset)
              .preference(key: ScrollViewHeightPreferenceKey.self,
                          value: height)
          })
      }
    }
    .coordinateSpace(name: scrollSpace)
    .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
      scrollOffset = value
    }
    .onPreferenceChange(ScrollViewHeightPreferenceKey.self) { value in
      scrollHeight = value
    }
  }
}
