import CoreGraphics
import Testing
@testable import TallyShotCore

private func fragment(_ text: String, y: CGFloat, height: CGFloat = 0.05) -> TextFragment {
    TextFragment(text: text, box: CGRect(x: 0, y: y, width: 0.2, height: height))
}

@Suite struct RowGrouperTests {
    @Test func returnsRowsTopToBottomRegardlessOfInputOrder() {
        #expect(RowGrouper.rows([fragment("c", y: 0.5), fragment("a", y: 0.1), fragment("b", y: 0.3)]) == [[1], [2], [0]])
    }

    @Test func slightlyOffsetFragmentsShareARow() {
        #expect(RowGrouper.rows([fragment("a", y: 0.10), fragment("b", y: 0.11)]) == [[0, 1]])
    }

    @Test func tallFragmentDoesNotChainNeighbouringRows() {
        let rows = RowGrouper.rows([
            fragment("a", y: 0.10),
            fragment("tall", y: 0.08, height: 0.20),
            fragment("b", y: 0.22),
        ])
        #expect(rows.count == 2)
    }
}
