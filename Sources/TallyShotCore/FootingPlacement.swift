import CoreGraphics

/// Where to draw each column total. All rects use AppKit screen coordinates (origin bottom-left).
public enum FootingPlacement {
    public struct Label: Equatable, Sendable {
        /// Screen x of the column's right edge. Totals right-align to it, like the numbers above.
        public let rightEdge: CGFloat
        public let size: CGSize

        public init(rightEdge: CGFloat, size: CGSize) {
            self.rightEdge = rightEdge
            self.size = size
        }
    }

    /// One frame per label, in input order.
    /// Labels sit just below the selection, else just above it, else just inside its bottom edge.
    /// A label that would overlap its right neighbour moves left.
    /// Labels too wide for the screen together may still overlap.
    public static func frames(
        for labels: [Label], selection: CGRect, visible: CGRect, gap: CGFloat = 6, spacing: CGFloat = 6
    ) -> [CGRect] {
        guard let height = labels.map(\.size.height).max() else { return [] }
        let y = row(height: height, selection: selection, visible: visible, gap: gap)

        var xs = Array(repeating: CGFloat(0), count: labels.count)
        var leftLimit = visible.maxX + spacing
        for index in labels.indices.sorted(by: { labels[$0].rightEdge > labels[$1].rightEdge }) {
            let label = labels[index]
            let right = min(label.rightEdge, leftLimit - spacing)
            xs[index] = right - label.size.width
            leftLimit = xs[index]
        }

        // Labels pushed past the left screen edge move right, nudging neighbours only as far as needed.
        var rightLimit = visible.minX
        for index in labels.indices.sorted(by: { xs[$0] < xs[$1] }) {
            xs[index] = max(xs[index], rightLimit)
            rightLimit = xs[index] + labels[index].size.width + spacing
        }

        return labels.indices.map { CGRect(x: xs[$0], y: y, width: labels[$0].size.width, height: height) }
    }

    private static func row(height: CGFloat, selection: CGRect, visible: CGRect, gap: CGFloat) -> CGFloat {
        let below = selection.minY - gap - height
        if below >= visible.minY { return below }
        let above = selection.maxY + gap
        if above + height <= visible.maxY { return above }
        return selection.minY + gap
    }
}
