import CoreGraphics
import Testing
@testable import Copaste

@MainActor
struct PanelPlacementTests {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 400, height: 200)

    @Test func zeroOffsetIsCentered() {
        let origin = PanelPlacement.origin(size: size, in: screen, offset: .zero)
        #expect(origin == CGPoint(x: 300, y: 300))
        #expect(PanelPlacement.offset(of: origin, size: size, in: screen) == .zero)
    }

    @Test func snapsOntoCenterLinesWhenClose() {
        let snap = PanelPlacement.snap(CGPoint(x: 310, y: 288), size: size, in: screen, distance: 16)
        #expect(snap == PanelPlacement.Snap(origin: CGPoint(x: 300, y: 300), centeredX: true, centeredY: true))
    }

    @Test func leavesFarPositionsAndKeepsTheWindowOnScreen() {
        let far = PanelPlacement.snap(CGPoint(x: 100, y: 300), size: size, in: screen, distance: 16)
        #expect(far == PanelPlacement.Snap(origin: CGPoint(x: 100, y: 300), centeredX: false, centeredY: true))
        let offScreen = PanelPlacement.snap(CGPoint(x: -50, y: 900), size: size, in: screen, distance: 16)
        #expect(offScreen.origin == CGPoint(x: 0, y: 600))
    }
}
