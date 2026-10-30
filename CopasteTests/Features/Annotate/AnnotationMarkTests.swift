import SwiftUI
import Testing
@testable import Copaste

@MainActor
struct AnnotationMarkTests {
    private let size = CGSize(width: 200, height: 100)

    private func rectangle() -> AnnotationMark {
        AnnotationMark(tool: .rectangle, color: .red, width: 0.01, points: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.4, y: 0.6)])
    }

    private func isClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        [lhs.minX - rhs.minX, lhs.minY - rhs.minY, lhs.width - rhs.width, lhs.height - rhs.height].allSatisfy { abs($0) < 0.001 }
    }

    @Test func hitTestUsesTheMarksBounds() {
        let mark = rectangle()
        #expect(mark.bounds(in: size) == CGRect(x: 40, y: 20, width: 40, height: 40))
        #expect(mark.contains(CGPoint(x: 60, y: 40), in: size))
        #expect(!mark.contains(CGPoint(x: 150, y: 90), in: size))
    }

    @Test func movingShiftsEveryPoint() {
        let moved = rectangle().moved(by: CGSize(width: 0.1, height: -0.1))
        #expect(isClose(moved.bounds(in: size), CGRect(x: 60, y: 10, width: 40, height: 40)))
    }

    @Test func resizingKeepsTheOppositeCornerInPlace() {
        // Drag the bottom-right corner (0.4, 0.6) to (0.6, 0.8); the top-left (0.2, 0.2) stays.
        let resized = rectangle().resized(anchor: CGPoint(x: 0.2, y: 0.2), from: CGPoint(x: 0.4, y: 0.6), to: CGPoint(x: 0.6, y: 0.8))
        #expect(isClose(resized.bounds(in: size), CGRect(x: 40, y: 20, width: 80, height: 60)))
    }

    @Test func resizingTextGrowsItsFont() {
        let text = AnnotationMark(tool: .text, color: .red, width: 0.01, points: [CGPoint(x: 0.1, y: 0.1)], text: "Hi")
        let bigger = text.resized(anchor: CGPoint(x: 0.1, y: 0.1), from: CGPoint(x: 0.3, y: 0.3), to: CGPoint(x: 0.5, y: 0.5))
        #expect(abs(bigger.width - 0.02) < 0.0001)
        #expect(bigger.points == text.points)
    }
}
