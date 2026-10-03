import CoreGraphics

public struct Table: Equatable, Sendable {
    /// Top to bottom. Rectangular: missing cells are "".
    public let rows: [[String]]

    public var columnCount: Int { rows.first?.count ?? 0 }
}

/// A table plus where each cell came from on screen.
public struct TableLayout: Equatable, Sendable {
    public let table: Table
    /// Fragment indices per cell, left to right. Parallel to `table.rows`.
    public let cellFragments: [[[Int]]]
    /// Normalised horizontal extent of each column, left to right.
    public let columnBands: [ClosedRange<CGFloat>]

    /// Normalised x of each boundary between neighbouring columns, left to right.
    public var columnSeparators: [CGFloat] {
        zip(columnBands, columnBands.dropFirst()).map { ($0.upperBound + $1.lowerBound) / 2 }
    }
}

/// Lays recognised fragments out as a grid.
///
/// Rows come from `RowGrouper`.
/// Columns are split at horizontal gaps that at most one fragment crosses.
/// One crossing fragment is read as a spanning cell (a title); two or more mean the gap is inside a column.
/// Known limit: a description wrapped over two lines becomes two rows.
public enum TableBuilder {
    public static func build(_ fragments: [TextFragment]) -> TableLayout {
        let columns = columnBands(fragments)
        let cellFragments = RowGrouper.rows(fragments).map { row in
            var cells = Array(repeating: [Int](), count: columns.count)
            for index in row {
                cells[column(of: fragments[index].box, in: columns)].append(index)
            }
            return cells.map { $0.sorted { fragments[$0].box.minX < fragments[$1].box.minX } }
        }
        let rows = cellFragments.map { row in
            row.map { members in members.map { fragments[$0].text }.joined(separator: " ") }
        }
        return TableLayout(table: Table(rows: rows), cellFragments: cellFragments, columnBands: columns)
    }

    /// A fragment that alone bridges two columns, such as a title above the table, is left out of the bands.
    static func columnBands(_ fragments: [TextFragment]) -> [ClosedRange<CGFloat>] {
        let spans = fragments.map { $0.box.minX...$0.box.maxX }
        let bandCount = union(spans).count
        let nonBridging = spans.indices.filter { index in
            var others = spans
            others.remove(at: index)
            return union(others).count <= bandCount
        }
        return union(nonBridging.map { spans[$0] })
    }

    /// The leftmost band the box overlaps, so a bridging fragment lands where it starts.
    private static func column(of box: CGRect, in bands: [ClosedRange<CGFloat>]) -> Int {
        bands.firstIndex { $0.overlaps(box.minX...box.maxX) } ?? 0
    }

    private static func union(_ spans: [ClosedRange<CGFloat>]) -> [ClosedRange<CGFloat>] {
        var merged: [ClosedRange<CGFloat>] = []
        for span in spans.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, span.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, span.upperBound)
            } else {
                merged.append(span)
            }
        }
        return merged
    }
}
