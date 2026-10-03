import CoreGraphics
import Testing
@testable import TallyShotCore

@Suite struct FootingPlacementTests {
    let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let selection = CGRect(x: 100, y: 300, width: 600, height: 300)
    let size = CGSize(width: 80, height: 20)

    @Test func rightAlignsUnderEachColumnBelowTheSelection() {
        let frames = FootingPlacement.frames(
            for: [.init(rightEdge: 400, size: size), .init(rightEdge: 700, size: size)],
            selection: selection, visible: visible)
        #expect(frames == [CGRect(x: 320, y: 274, width: 80, height: 20), CGRect(x: 620, y: 274, width: 80, height: 20)])
    }

    @Test func overlappingLabelMovesLeft() {
        let frames = FootingPlacement.frames(
            for: [.init(rightEdge: 650, size: size), .init(rightEdge: 700, size: size)],
            selection: selection, visible: visible)
        #expect(frames.map(\.minX) == [534, 620])
        #expect(frames[0].maxX + 6 == frames[1].minX)
    }

    @Test func goesAboveWhenNoRoomBelow() {
        let low = CGRect(x: 100, y: 10, width: 600, height: 300)
        let frames = FootingPlacement.frames(for: [.init(rightEdge: 700, size: size)], selection: low, visible: visible)
        #expect(frames.first?.minY == 316)
    }

    @Test func goesInsideWhenNoRoomAboveOrBelow() {
        let full = CGRect(x: 0, y: 5, width: 1000, height: 790)
        let frames = FootingPlacement.frames(for: [.init(rightEdge: 700, size: size)], selection: full, visible: visible)
        #expect(frames.first?.minY == 11)
    }

    @Test func staysOnScreenAtBothEdges() {
        let frames = FootingPlacement.frames(
            for: [.init(rightEdge: 30, size: size), .init(rightEdge: 1100, size: size)],
            selection: selection, visible: visible)
        #expect(frames.map(\.minX) == [0, 920])
    }

    @Test func pushingRightFromTheLeftEdgeKeepsLabelsApart() {
        let frames = FootingPlacement.frames(
            for: [.init(rightEdge: 30, size: size), .init(rightEdge: 120, size: size)],
            selection: selection, visible: visible)
        #expect(frames.map(\.minX) == [0, 86])
    }

    @Test func keepsInputOrder() {
        let frames = FootingPlacement.frames(
            for: [.init(rightEdge: 700, size: size), .init(rightEdge: 400, size: size)],
            selection: selection, visible: visible)
        #expect(frames.map(\.maxX) == [700, 400])
    }

    @Test func noLabelsNoFrames() {
        #expect(FootingPlacement.frames(for: [], selection: selection, visible: visible).isEmpty)
    }
}
