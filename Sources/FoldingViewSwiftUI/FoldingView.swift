/*
 * FILE:	FoldingView.swift
 * DESCRIPTION:	FoldingViewSwiftUI: View with Headline and Folding Details
 * DATE:	Sat, May 21 2022
 * UPDATED:	Sat, May 28 2022
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		https://www.MagickWorX.COM/
 * COPYRIGHT:	(c) 2022 阿部康一／Kouichi ABE (WALL)
 * LICENSE:	The 2-Clause BSD License (See LICENSE.txt)
 */

import SwiftUI

// MARK: - FoldingView
public struct FoldingView<Headline,Detail>: View where Headline: View, Detail: View
{
  @ObservedObject private var state: FoldingState = .init()

  private let duration: Int // Duration for animating Detail View [msec]
  private let headline: () -> Headline
  private var details: [DetailView<Detail>] = []

  // Controls the open/close state of DetailView
  @State private var isOpened: Bool = false

  public init(duration: TimeInterval = 0.25, headline: @escaping () -> Headline, details: [Detail]) {
    self.duration = Int(duration * 1000) // to milliseconds
    self.headline = headline
    defer {
      self.details = details.map({ detail in DetailView(state: state, duration: duration, content: { detail }) })
      self.state.prepare(ids: self.details.map({ $0.id }))
    }
  }

  @ViewBuilder
  public var body: some View {
    LazyVStack(spacing: 0.0) {
      headline().gesture(tap)
      ForEach(details) {
        (detail) in
        detail
      }
    }
  }
}

extension FoldingView
{
  private var tap: some Gesture {
    TapGesture(count: 1)
      .onEnded { _ in
        self.handleTapGesture()
      }
  }

  private func handleTapGesture() {
    /*
     * The animations are excuted with a staggered start time.
     * So these DetailViews are display in order.
     * When closing, execute in reverse order.
     */
    if self.isOpened {
      for (i,detail) in details.reversed().enumerated() {
        let t = duration * (i + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(t)) {
          self.state.fold(id: detail.id)
        }
      }
    }
    else {
      for (i,detail) in details.enumerated() {
        let t = duration * (i + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(t)) {
          self.state.unfold(id: detail.id)
        }
      }
    }
    self.isOpened.toggle()
  }
}


/*
 * Reference:
 * ios - Unable to update/modify SwiftUI View's @state var - Stack Overflow
 * https://stackoverflow.com/questions/59783686/unable-to-update-modify-swiftui-views-state-var
 */

// MARK: - FoldingState
final class FoldingState: ObservableObject
{
  // To manage the open/closed state of DetailView.
  @Published private(set) var isOpened: [String:Bool] = [:]

  func fold(id: String) {
    isOpened[id] = false
  }

  func unfold(id: String) {
    isOpened[id] = true
  }

  // To initialize the open/closed state of DetailView called from FoldingView.
  func prepare(ids: [String]) {
    for id in ids {
      isOpened[id] = false
    }
  }
}

// MARK: - DetailView
struct DetailView<Content>: View where Content: View
{
  let id: String = UUID().uuidString

  @ObservedObject var state: FoldingState
  let duration: TimeInterval // [sec]
  let content: () -> Content

  @ViewBuilder
  var body: some View {
    if self.state.isOpened[id] ?? false {
      content()
        .transition(.folding.animation(.easeInOut(duration: duration)))
    }
  }
}

extension DetailView: Identifiable, Hashable
{
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func ==(lhs: Self, rhs: Self) -> Bool {
    return lhs.id == rhs.id
  }
}

// MARK: - Custom ViewModifier
struct FoldingViewModifier: ViewModifier
{
  private let angle: Double
  private let anchor: UnitPoint

  // "x: 1" means the horizontal rotation.
  private let axis: (x: CGFloat, y: CGFloat, z: CGFloat) = (x: 1, y: 0, z: 0)

  init(angle: Double, anchor: UnitPoint = .top) {
    self.angle = angle
    self.anchor = anchor
  }

  func body(content: Content) -> some View {
    content
      .rotation3DEffect(.degrees(angle), axis: axis, anchor: anchor)
      .clipped()
  }
}

extension AnyTransition
{
  static var folding: AnyTransition {
    .modifier(
        active: FoldingViewModifier(angle: -90),
      identity: FoldingViewModifier(angle: 0)
    )
  }
}

// MARK: - Preview
struct FoldingView_Previews: PreviewProvider
{
  static var previews: some View {
    ScrollView(showsIndicators: false) {
      FoldingView(duration: 0.3, headline: {
        ZStack {
          Color.teal
          HStack {
            Image(systemName: "scroll")
              .resizable()
              .frame(width: 48.0, height: 48.0)
              .padding()
            Text("Welcome to FoldingView!\nTap here!")
              .lineLimit(nil)
          }
          .foregroundColor(.black)
          .frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: 300.0, maxHeight: 80.0)
      }, details: [
        DetailView(title: "Detail Red", color: .red),
        DetailView(title: "Detail Green", color: .green),
        DetailView(title: "Detail Blue", color: .blue),
        DetailView(title: "Detail Orange", color: .orange, height: 150.0),
        DetailView(title: "Detail Purple", color: .purple, height: 280.0),
        /*
        DetailView(title: "Detail Indigo", color: .indigo),
        DetailView(title: "Detail Mint", color: .mint, height: 200.0),
        DetailView(title: "Detail Brown", color: .brown, height: 110.0),
        DetailView(title: "Detail Teal", color: .teal),
        */
      ])
    }
  }

  struct DetailView: View
  {
    let title: String
    let color: Color
    var height: CGFloat = 80.0

    @ViewBuilder
    var body: some View {
      ZStack {
        color
        Text(title).font(.title)
      }
      .frame(minHeight: height)
      .frame(maxWidth: 300.0, maxHeight: height)
    }
  }
}
