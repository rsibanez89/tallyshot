import CoreGraphics
import Foundation
import Testing
@testable import TallyShotCore

@Suite struct AmountFormatterTests {
    @Test func displayGroupsThousands() {
        #expect(AmountFormatter.display(Decimal(string: "-1234.5")!, fractionDigits: 2) == "-1,234.50")
    }

    @Test func plainHasNoGrouping() {
        #expect(AmountFormatter.plain(Decimal(string: "1234567.8")!, fractionDigits: 2) == "1234567.80")
    }

    @Test func integersStayIntegers() {
        #expect(AmountFormatter.display(42, fractionDigits: 0) == "42")
    }
}

@Suite struct PanelPlacementTests {
    let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let panel = CGSize(width: 200, height: 150)

    @Test func prefersRightTopAligned() {
        let selection = CGRect(x: 100, y: 300, width: 100, height: 200)
        #expect(PanelPlacement.origin(panelSize: panel, selection: selection, visible: visible) == CGPoint(x: 212, y: 350))
    }

    @Test func fallsBackToLeft() {
        let selection = CGRect(x: 700, y: 300, width: 200, height: 200)
        #expect(PanelPlacement.origin(panelSize: panel, selection: selection, visible: visible) == CGPoint(x: 488, y: 350))
    }

    @Test func fallsBackToBelowForWideSelections() {
        let selection = CGRect(x: 50, y: 300, width: 900, height: 200)
        #expect(PanelPlacement.origin(panelSize: panel, selection: selection, visible: visible) == CGPoint(x: 50, y: 138))
    }

    @Test func clampsIntoVisibleFrame() {
        let selection = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let origin = PanelPlacement.origin(panelSize: panel, selection: selection, visible: visible)
        #expect(visible.contains(CGRect(origin: origin, size: panel)))
    }
}
