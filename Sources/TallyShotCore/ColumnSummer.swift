import Foundation

public struct CellAmount: Equatable, Sendable {
    public let amount: Amount
    public let row: Int
    /// The fragment holding the amount. `amount.range` indexes its text.
    public let fragmentIndex: Int
}

public struct ColumnSum: Equatable, Sendable {
    public let column: Int
    /// The nearest text cell above the first amount, usually the column header.
    public let header: String?
    /// Top to bottom.
    public let cells: [CellAmount]

    public var total: Decimal { total(excluding: []) }

    /// `excluded` holds indices into `cells`.
    public func total(excluding excluded: Set<Int>) -> Decimal {
        cells.indices
            .filter { !excluded.contains($0) }
            .reduce(Decimal(0)) { $0 + cells[$1].amount.value }
    }

    public var fractionDigits: Int { cells.map(\.amount.fractionDigits).max() ?? 0 }
}

/// Totals every numeric column of a table.
///
/// A cell counts only when it is one fragment whose whole text is one amount,
/// so "12 of 12 results", "28 Jun 2026" and headers never count.
/// A column is numeric when at least half its non-empty cells, header aside, are amounts.
public enum ColumnSummer {
    public static func sums(_ layout: TableLayout, fragments: [TextFragment]) -> [ColumnSum] {
        (0..<layout.table.columnCount).compactMap { sum(column: $0, layout: layout, fragments: fragments) }
    }

    private static func sum(column: Int, layout: TableLayout, fragments: [TextFragment]) -> ColumnSum? {
        let cells = layout.cellFragments.map { $0[column] }
        let amounts: [CellAmount?] = cells.enumerated().map { row, members in
            guard members.count == 1, let amount = wholeAmount(fragments[members[0]].text) else { return nil }
            return CellAmount(amount: amount, row: row, fragmentIndex: members[0])
        }
        guard let firstRow = amounts.firstIndex(where: { $0 != nil }) else { return nil }

        let header = layout.table.rows[..<firstRow].map { $0[column] }.last { !$0.isEmpty }
        let found = amounts.compactMap { $0 }
        let nonEmptyBesidesHeader = cells.filter { !$0.isEmpty }.count - (header == nil ? 0 : 1)
        guard found.count * 2 >= nonEmptyBesidesHeader else { return nil }

        return ColumnSum(column: column, header: header, cells: found)
    }

    /// The amount, when it is the text's only content apart from spaces.
    static func wholeAmount(_ text: String) -> Amount? {
        let amounts = AmountParser.amounts(in: text)
        guard amounts.count == 1, let amount = amounts.first else { return nil }
        let outside = text[..<amount.range.lowerBound] + text[amount.range.upperBound...]
        return outside.allSatisfy(\.isWhitespace) ? amount : nil
    }
}
