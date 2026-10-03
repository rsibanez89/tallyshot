import Combine
import Foundation
import TallyShotCore

enum ResultTab: Int, CaseIterable {
    case sum, table, text

    var title: String {
        switch self {
        case .sum: "Sum"
        case .table: "Table"
        case .text: "Text"
        }
    }
}

/// One amount: `column` indexes `ResultModel.columns`, `cell` that column's values.
struct CellRef: Hashable {
    let column: Int
    let cell: Int
}

struct ColumnSummary {
    let title: String
    let sum: ColumnSum
    /// Every value, excluded or not, top to bottom.
    let values: [String]

    init(_ sum: ColumnSum) {
        self.sum = sum
        title = sum.header ?? "Column \(sum.column + 1)"
        values = sum.cells.map { AmountFormatter.display($0.amount.value, fractionDigits: sum.fractionDigits) }
    }
}

/// One capture, three views of it.
/// The tab and the summed column's header are remembered for the next capture.
@MainActor
final class ResultModel: ObservableObject {
    private static let lastTabKey = "lastTab"
    private static let lastColumnKey = "lastSumColumn"

    @Published var tab: ResultTab {
        didSet { UserDefaults.standard.set(tab.rawValue, forKey: Self.lastTabKey) }
    }
    /// Index into `columns`.
    @Published var selectedColumn: Int {
        didSet {
            UserDefaults.standard.set(columns[selectedColumn].title, forKey: Self.lastColumnKey)
            lastCopied = nil
        }
    }
    /// Amounts left out of every total.
    @Published private(set) var excluded: Set<CellRef> = []
    /// Title of the last copy button used, to label it "Copied". Cleared when totals change.
    @Published private(set) var lastCopied: String?

    /// Numeric columns, left to right. Empty when the selection holds no numbers.
    let columns: [ColumnSummary]
    let table: Table
    let plainText: String

    var selected: ColumnSummary? { columns.isEmpty ? nil : columns[selectedColumn] }

    init(_ analysis: Analysis) {
        columns = analysis.columnSums.map(ColumnSummary.init)
        table = analysis.layout.table
        plainText = TableExporter.plainText(analysis.layout.table)

        // Leftmost by default: on bank statements the rightmost numeric column is usually the balance.
        let lastColumn = UserDefaults.standard.string(forKey: Self.lastColumnKey)
        selectedColumn = columns.firstIndex { $0.title.caseInsensitiveCompare(lastColumn ?? "") == .orderedSame } ?? 0

        let lastTab = ResultTab(rawValue: UserDefaults.standard.integer(forKey: Self.lastTabKey)) ?? .sum
        tab = (lastTab == .sum && columns.isEmpty) ? .text : lastTab
    }

    func toggle(_ cell: CellRef) {
        if excluded.contains(cell) {
            excluded.remove(cell)
        } else {
            excluded.insert(cell)
        }
        lastCopied = nil
    }

    func isExcluded(_ cell: CellRef) -> Bool {
        excluded.contains(cell)
    }

    func total(ofColumn column: Int) -> String {
        let sum = columns[column].sum
        return AmountFormatter.display(sum.total(excluding: excludedCells(in: column)), fractionDigits: sum.fractionDigits)
    }

    func plainTotal(ofColumn column: Int) -> String {
        let sum = columns[column].sum
        return AmountFormatter.plain(sum.total(excluding: excludedCells(in: column)), fractionDigits: sum.fractionDigits)
    }

    /// Included values only, one per line.
    func plainValues(ofColumn column: Int) -> String {
        let sum = columns[column].sum
        let excludedCells = excludedCells(in: column)
        return sum.cells.indices
            .filter { !excludedCells.contains($0) }
            .map { AmountFormatter.plain(sum.cells[$0].amount.value, fractionDigits: sum.fractionDigits) }
            .joined(separator: "\n")
    }

    func copy(_ title: String, _ write: () -> Void) {
        write()
        lastCopied = title
    }

    private func excludedCells(in column: Int) -> Set<Int> {
        Set(excluded.filter { $0.column == column }.map(\.cell))
    }
}
