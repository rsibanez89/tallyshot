import CoreGraphics

/// Where to put the result panel. All rects use AppKit screen coordinates (origin bottom-left).
public enum PanelPlacement {
    /// Prefers right of the selection, then left, then below, then above; always clamped to `visible`.
    public static func origin(panelSize: CGSize, selection: CGRect, visible: CGRect, gap: CGFloat = 12) -> CGPoint {
        let topAligned = selection.maxY - panelSize.height
        let right = CGPoint(x: selection.maxX + gap, y: topAligned)
        let left = CGPoint(x: selection.minX - gap - panelSize.width, y: topAligned)
        let below = CGPoint(x: selection.minX, y: selection.minY - gap - panelSize.height)
        let above = CGPoint(x: selection.minX, y: selection.maxY + gap)

        let chosen: CGPoint
        if right.x + panelSize.width <= visible.maxX {
            chosen = right
        } else if left.x >= visible.minX {
            chosen = left
        } else if below.y >= visible.minY {
            chosen = below
        } else {
            chosen = above
        }
        return clamp(chosen, size: panelSize, into: visible)
    }

    private static func clamp(_ point: CGPoint, size: CGSize, into visible: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, visible.minX), visible.maxX - size.width),
            y: min(max(point.y, visible.minY), visible.maxY - size.height)
        )
    }
}
