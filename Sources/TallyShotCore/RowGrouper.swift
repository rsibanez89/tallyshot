import CoreGraphics

/// One line of recognised text.
public struct TextFragment: Equatable, Sendable {
    public let text: String
    /// Normalised to the captured image: 0...1, origin top-left, y grows downward.
    public let box: CGRect

    public init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}

enum RowGrouper {
    /// Fragment indices grouped into visual rows, top to bottom.
    /// Fragments share a row when their vertical spans overlap by at least half the shorter height.
    /// Each row keeps its first fragment's band, so a tall fragment cannot chain two rows together.
    static func rows(_ fragments: [TextFragment]) -> [[Int]] {
        let topToBottom = fragments.indices.sorted { fragments[$0].box.midY < fragments[$1].box.midY }
        var rows: [(band: CGRect, members: [Int])] = []
        for index in topToBottom {
            let box = fragments[index].box
            if let last = rows.last,
               verticalOverlap(last.band, box) >= 0.5 * min(last.band.height, box.height) {
                rows[rows.count - 1].members.append(index)
            } else {
                rows.append((band: box, members: [index]))
            }
        }
        return rows.map(\.members)
    }

    private static func verticalOverlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(0, min(a.maxY, b.maxY) - max(a.minY, b.minY))
    }
}
