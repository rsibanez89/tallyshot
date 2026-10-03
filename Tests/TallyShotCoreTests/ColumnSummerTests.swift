import CoreGraphics
import Foundation
import Testing
@testable import TallyShotCore

private func cell(_ text: String, x: CGFloat, width: CGFloat, row: Int) -> TextFragment {
    TextFragment(text: text, box: CGRect(x: x, y: 0.1 + CGFloat(row) * 0.06, width: width, height: 0.04))
}

private func dec(_ s: String) -> Decimal { Decimal(string: s)! }

/// Shaped like a real bank page: title with a result count, an empty "Money in" column, a balance column.
private let transactions: [TextFragment] = {
    var fragments = [
        cell("Transaction history", x: 0.07, width: 0.18, row: 0),
        cell("12 of 12 results", x: 0.86, width: 0.09, row: 0),
        cell("Date", x: 0.08, width: 0.04, row: 1),
        cell("Description", x: 0.24, width: 0.08, row: 1),
        cell("Money in", x: 0.60, width: 0.07, row: 1),
        cell("Money out", x: 0.71, width: 0.08, row: 1),
        cell("Balance", x: 0.89, width: 0.06, row: 1),
    ]
    for (row, balance) in ["-$4,022.77", "-$4,075.82", "-$1,469.28"].enumerated() {
        fragments += [
            cell("28 Jun 2026", x: 0.08, width: 0.09, row: row + 2),
            cell("TPG INTERNET PTY LTD", x: 0.24, width: 0.18, row: row + 2),
            cell("-$74.99", x: 0.73, width: 0.06, row: row + 2),
            cell(balance, x: 0.87, width: 0.08, row: row + 2),
        ]
    }
    return fragments
}()

@Suite struct ColumnSummerTests {
    let sums = ColumnSummer.sums(TableBuilder.build(transactions), fragments: transactions)

    @Test func totalsEveryNumericColumn() {
        #expect(sums.map(\.header) == ["Money out", "Balance"])
        #expect(sums.map(\.total) == [dec("-224.97"), dec("-9567.87")])
    }

    @Test func excludedCellsLeaveTheTotal() {
        let moneyOut = sums[0]
        #expect(moneyOut.total(excluding: [1]) == dec("-149.98"))
        #expect(moneyOut.total(excluding: [0, 1, 2]) == 0)
        #expect(moneyOut.total(excluding: []) == moneyOut.total)
    }

    @Test func resultCountInTheTitleIsNotAnAmount() {
        #expect(sums.last?.cells.count == 3)
    }

    @Test func emptyColumnIsNotListed() {
        #expect(!sums.contains { $0.header == "Money in" })
    }

    @Test func cellsPointAtTheirFragmentAndRow() {
        let first = try! #require(sums.first?.cells.first)
        #expect(transactions[first.fragmentIndex].text == "-$74.99")
        #expect(first.row == 2)
    }

    @Test func singleColumnWithoutHeader() {
        let column = [cell("10.00", x: 0, width: 0.1, row: 0), cell("-2.50", x: 0, width: 0.1, row: 1)]
        let sums = ColumnSummer.sums(TableBuilder.build(column), fragments: column)
        #expect(sums.count == 1)
        #expect(sums[0].header == nil)
        #expect(sums[0].total == dec("7.50"))
        #expect(sums[0].fractionDigits == 2)
    }

    @Test(arguments: [["Coffee", "Rent", "1234", "Fuel"], ["Coffee", "Rent", "Fuel", "1234"]])
    func textColumnWithAStrayNumberIsNotNumeric(texts: [String]) {
        let rows = texts.enumerated().map { cell($1, x: 0, width: 0.1, row: $0) }
        #expect(ColumnSummer.sums(TableBuilder.build(rows), fragments: rows).isEmpty)
    }

    @Test(arguments: [("-$74.99", true), ("  45.00 ", true), ("12 of 12 results", false), ("28 Jun 2026", false), ("5 10", false)])
    func wholeAmount(text: String, isAmount: Bool) {
        #expect((ColumnSummer.wholeAmount(text) != nil) == isAmount)
    }
}
