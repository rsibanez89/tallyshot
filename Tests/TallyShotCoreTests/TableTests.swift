import CoreGraphics
import Testing
@testable import TallyShotCore

private func cell(_ text: String, x: CGFloat, width: CGFloat, row: Int) -> TextFragment {
    TextFragment(text: text, box: CGRect(x: x, y: 0.1 + CGFloat(row) * 0.1, width: width, height: 0.05))
}

/// Date | Description | Amount, with ragged widths as Vision returns them.
private let statement: [TextFragment] = [
    cell("Date", x: 0.02, width: 0.08, row: 0),
    cell("Description", x: 0.20, width: 0.15, row: 0),
    cell("Amount", x: 0.70, width: 0.10, row: 0),
    cell("12/09/2026", x: 0.02, width: 0.14, row: 1),
    cell("WOOLWORTHS 1234 SYDNEY", x: 0.20, width: 0.38, row: 1),
    cell("-$45.20", x: 0.70, width: 0.09, row: 1),
    cell("13/09/2026", x: 0.02, width: 0.14, row: 2),
    cell("UBER *TRIP", x: 0.20, width: 0.16, row: 2),
    cell("($1,200.00)", x: 0.70, width: 0.14, row: 2),
]

@Suite struct TableBuilderTests {
    @Test func buildsAGridFromRaggedCells() {
        #expect(TableBuilder.build(statement).table.rows == [
            ["Date", "Description", "Amount"],
            ["12/09/2026", "WOOLWORTHS 1234 SYDNEY", "-$45.20"],
            ["13/09/2026", "UBER *TRIP", "($1,200.00)"],
        ])
    }

    @Test func emptyCellsStayInTheirColumn() {
        let table = TableBuilder.build([
            cell("a", x: 0.0, width: 0.1, row: 0), cell("b", x: 0.5, width: 0.1, row: 0),
            cell("c", x: 0.5, width: 0.1, row: 1),
        ]).table
        #expect(table.rows == [["a", "b"], ["", "c"]])
    }

    @Test func titleSpanningColumnsDoesNotMergeThem() {
        let titled = [cell("September statement for account 123", x: 0.02, width: 0.7, row: -1)] + statement
        let table = TableBuilder.build(titled).table
        #expect(table.columnCount == 3)
        #expect(table.rows.first == ["September statement for account 123", "", ""])
    }

    @Test func fragmentsInTheSameCellAreJoinedLeftToRight() {
        // Two rows cross the gap, so it is not a column boundary.
        let table = TableBuilder.build([
            cell("SYDNEY", x: 0.30, width: 0.10, row: 0),
            cell("WOOLWORTHS", x: 0.10, width: 0.15, row: 0),
            cell("COLES MELBOURNE", x: 0.10, width: 0.30, row: 1),
            cell("ALDI BRISBANE", x: 0.10, width: 0.28, row: 2),
        ]).table
        #expect(table.rows == [["WOOLWORTHS SYDNEY"], ["COLES MELBOURNE"], ["ALDI BRISBANE"]])
    }

    @Test func separatorsSitMidwayBetweenColumns() {
        let separators = TableBuilder.build(statement).columnSeparators
        #expect(separators.count == 2)
        #expect(abs(separators[0] - 0.18) < 0.0001)  // Date ends 0.16, Description starts 0.20.
        #expect(abs(separators[1] - 0.64) < 0.0001)  // Description ends 0.58, Amount starts 0.70.
    }

    @Test func cellsRememberTheirFragments() {
        let layout = TableBuilder.build(statement)
        #expect(layout.cellFragments[1] == [[3], [4], [5]])
    }

    @Test func noFragmentsIsAnEmptyTable() {
        let table = TableBuilder.build([]).table
        #expect(table.rows.isEmpty)
        #expect(table.columnCount == 0)
    }
}

@Suite struct TableExporterTests {
    let table = Table(rows: [["Item", "Amount"], ["Fish & <chips>", "$1,020.00"], ["a|b", ""]])

    @Test func tsvSeparatesCellsWithTabs() {
        #expect(TableExporter.tsv(table) == "Item\tAmount\nFish & <chips>\t$1,020.00\na|b\t")
    }

    @Test func tsvFlattensTabsAndNewlinesInsideCells() {
        #expect(TableExporter.tsv(Table(rows: [["a\tb", "c\nd"]])) == "a b\tc d")
    }

    @Test func htmlEscapesCellText() {
        #expect(TableExporter.html(table) == """
            <meta charset="utf-8"><table><tr><td>Item</td><td>Amount</td></tr>\
            <tr><td>Fish &amp; &lt;chips&gt;</td><td>$1,020.00</td></tr>\
            <tr><td>a|b</td><td></td></tr></table>
            """)
    }

    @Test func markdownUsesFirstRowAsHeaderAndEscapesPipes() {
        #expect(TableExporter.markdown(table) == """
            | Item | Amount |
            | --- | --- |
            | Fish & <chips> | $1,020.00 |
            | a\\|b |  |
            """)
    }

    @Test func markdownOfASingleRowIsHeaderOnly() {
        #expect(TableExporter.markdown(Table(rows: [["x"]])) == "| x |\n| --- |")
    }

    @Test func emptyTableExportsNothing() {
        let empty = Table(rows: [])
        #expect(TableExporter.markdown(empty) == "")
        #expect(TableExporter.tsv(empty) == "")
    }

    @Test func plainTextSkipsEmptyCells() {
        #expect(TableExporter.plainText(table) == "Item Amount\nFish & <chips> $1,020.00\na|b")
    }
}
