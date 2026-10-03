import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI
import TallyShotCore
import os

/// Shows the result: a highlight over the selection, column totals under it, and a panel beside it.
/// Everything stays up until Esc, the panel's close button, or the next capture.
/// On the Sum tab, hovering an amount offers ✕ to leave it out of the totals and ✓ to bring it back.
@MainActor
final class ResultPresenter {
    private var panel: ResultPanel?
    private var highlight: HighlightWindow?
    private var footing: FootingWindow?
    private var escape: HotKey?
    private var subscriptions: Set<AnyCancellable> = []
    private let log = Logger(subsystem: "local.tallyshot", category: "result")

    func show(_ content: PanelContent, selection: Selection, analysis: Analysis? = nil) {
        dismiss()
        registerEscape()

        let highlight = HighlightWindow(selection: selection.rect)
        highlight.orderFrontRegardless()
        self.highlight = highlight

        if case .result(let model) = content, let analysis {
            highlight.onToggle = { [weak model] in model?.toggle($0) }
            model.$tab.combineLatest(model.$excluded)
                .sink { tab, excluded in
                    highlight.marks = Self.marks(tab: tab, excluded: excluded, analysis: analysis)
                }
                .store(in: &subscriptions)

            if !model.columns.isEmpty {
                let footing = FootingWindow(selection: selection)
                footing.orderFrontRegardless()
                self.footing = footing
                // `$excluded` publishes before the change lands, so read the model on the next turn.
                model.$excluded
                    .receive(on: RunLoop.main)
                    .sink { [weak model] _ in
                        guard let model else { return }
                        footing.show(Self.footingTotals(model: model, analysis: analysis, selection: selection))
                    }
                    .store(in: &subscriptions)
                footing.show(Self.footingTotals(model: model, analysis: analysis, selection: selection))
            }
        }

        let panel = ResultPanel(rootView: ResultView(content: content))
        let occupied = footing.map { selection.rect.union($0.frame) } ?? selection.rect
        panel.setFrameOrigin(PanelPlacement.origin(
            panelSize: panel.frame.size, selection: occupied, visible: selection.screen.visibleFrame))
        panel.onDismiss = { [weak self] in self?.dismiss() }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        let panel = self.panel
        self.panel = nil
        panel?.onDismiss = nil
        panel?.close()
        subscriptions.removeAll()
        escape = nil
        highlight?.orderOut(nil)
        highlight = nil
        footing?.orderOut(nil)
        footing = nil
    }

    /// Esc is taken from every app while a result is up, so it works after clicking elsewhere.
    private func registerEscape() {
        do {
            escape = try HotKey(keyCode: UInt32(kVK_Escape), modifiers: 0) { [weak self] in
                // Dismissing unregisters this hot key, so leave its Carbon callback first.
                DispatchQueue.main.async { self?.dismiss() }
            }
        } catch {
            log.error("escape hotkey unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    /// Sum tab: every numeric column's amounts. Table tab: column boundaries.
    private static func marks(tab: ResultTab, excluded: Set<CellRef>, analysis: Analysis) -> HighlightMarks {
        switch tab {
        case .sum:
            .amounts(analysis.amountBoxes.enumerated().flatMap { column, boxes in
                boxes.enumerated().map { cell, box in
                    let ref = CellRef(column: column, cell: cell)
                    return AmountMark(cell: ref, box: box, isExcluded: excluded.contains(ref))
                }
            })
        case .table: .columnSeparators(analysis.layout.columnSeparators)
        case .text: .none
        }
    }

    /// `model.columns` and `analysis.columnSums` are parallel.
    private static func footingTotals(
        model: ResultModel, analysis: Analysis, selection: Selection
    ) -> [FootingWindow.Total] {
        analysis.columnSums.enumerated().map { index, sum in
            let band = analysis.layout.columnBands[sum.column]
            return FootingWindow.Total(
                text: model.total(ofColumn: index),
                plain: model.plainTotal(ofColumn: index),
                rightEdge: selection.rect.minX + band.upperBound * selection.rect.width)
        }
    }
}

private final class ResultPanel: NSPanel {
    var onDismiss: (() -> Void)?
    private var isClosing = false

    init(rootView: some View) {
        super.init(
            contentRect: .zero, styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        title = "TallyShot"
        level = .floating
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        let host = NSHostingView(rootView: rootView)
        contentView = host
        setContentSize(host.fittingSize)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func close() {
        guard !isClosing else { return }
        isClosing = true
        super.close()
        onDismiss?()
    }
}

/// `box` is normalised to the selection, origin top-left.
private struct AmountMark {
    let cell: CellRef
    let box: CGRect
    let isExcluded: Bool
}

private enum HighlightMarks {
    case none
    case amounts([AmountMark])
    /// Normalised x.
    case columnSeparators([CGFloat])
}

private final class HighlightWindow: NSWindow {
    /// Room around the selection for the ✕ / ✓ badges.
    private static let margin: CGFloat = 12
    private let highlightView: HighlightView

    var marks: HighlightMarks {
        get { highlightView.marks }
        set { highlightView.marks = newValue }
    }

    var onToggle: ((CellRef) -> Void)? {
        get { highlightView.onToggle }
        set { highlightView.onToggle = newValue }
    }

    init(selection: CGRect) {
        let frame = selection.insetBy(dx: -Self.margin, dy: -Self.margin)
        highlightView = HighlightView(
            selection: CGRect(origin: CGPoint(x: Self.margin, y: Self.margin), size: selection.size))
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = highlightView
    }
}

private final class HighlightView: NSView {
    private static let badgeSize: CGFloat = 18

    /// In view coordinates.
    private let selection: CGRect
    var marks = HighlightMarks.none {
        didSet {
            updateTrackingAreas()
            needsDisplay = true
        }
    }
    var onToggle: ((CellRef) -> Void)?
    private var hovered: CellRef?

    init(selection: CGRect) {
        self.selection = selection
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var amountMarks: [AmountMark] {
        if case .amounts(let marks) = marks { marks } else { [] }
    }

    // MARK: Hover and click

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        for mark in amountMarks {
            let rect = markRect(mark).union(badgeRect(mark))
            addTrackingArea(NSTrackingArea(
                rect: rect, options: [.mouseEnteredAndExited, .activeAlways], owner: self,
                userInfo: ["cell": mark.cell]))
        }
        if let hovered, !amountMarks.contains(where: { $0.cell == hovered }) { self.hovered = nil }
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = event.trackingArea?.userInfo?["cell"] as? CellRef
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        if hovered == event.trackingArea?.userInfo?["cell"] as? CellRef {
            hovered = nil
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let mark = amountMarks.first(where: { $0.cell == hovered }), badgeRect(mark).contains(point) {
            onToggle?(mark.cell)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemGreen.setStroke()
        let outline = NSBezierPath(rect: selection.insetBy(dx: -1, dy: -1))
        outline.lineWidth = 2
        outline.setLineDash([6, 4], count: 2, phase: 0)
        outline.stroke()

        switch marks {
        case .none:
            break
        case .amounts(let marks):
            marks.forEach(draw)
            if let mark = marks.first(where: { $0.cell == hovered }) { drawBadge(mark) }
        case .columnSeparators(let xs):
            NSColor.systemGreen.setStroke()
            for x in xs {
                let viewX = selection.minX + x * selection.width
                let line = NSBezierPath()
                line.move(to: NSPoint(x: viewX, y: selection.minY))
                line.line(to: NSPoint(x: viewX, y: selection.maxY))
                line.lineWidth = 1.5
                line.setLineDash([4, 3], count: 2, phase: 0)
                line.stroke()
            }
        }
    }

    private func draw(_ mark: AmountMark) {
        let color = mark.isExcluded ? NSColor.systemGray : NSColor.systemGreen
        let marker = NSBezierPath(roundedRect: markRect(mark), xRadius: 3, yRadius: 3)
        color.withAlphaComponent(mark.isExcluded ? 0.3 : 0.15).setFill()
        marker.fill()
        color.setStroke()
        marker.lineWidth = 1.5
        marker.stroke()
    }

    /// ✕ on an included amount, ✓ on an excluded one.
    private func drawBadge(_ mark: AmountMark) {
        let (symbol, color) = mark.isExcluded
            ? ("checkmark.circle.fill", NSColor.systemGreen)
            : ("xmark.circle.fill", NSColor.systemRed)
        let configuration = NSImage.SymbolConfiguration(pointSize: Self.badgeSize, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white, color]))
        NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)?
            .draw(in: badgeRect(mark))
    }

    private func markRect(_ mark: AmountMark) -> CGRect {
        CGRect(
            x: selection.minX + mark.box.minX * selection.width,
            y: selection.minY + (1 - mark.box.maxY) * selection.height,
            width: mark.box.width * selection.width,
            height: mark.box.height * selection.height
        ).insetBy(dx: -2, dy: -2)
    }

    /// Centred on the mark's top-right corner.
    private func badgeRect(_ mark: AmountMark) -> CGRect {
        let corner = CGPoint(x: markRect(mark).maxX, y: markRect(mark).maxY)
        return CGRect(
            x: corner.x - Self.badgeSize / 2, y: corner.y - Self.badgeSize / 2,
            width: Self.badgeSize, height: Self.badgeSize)
    }
}

/// Column totals drawn just outside the selection, right-aligned under their columns.
/// Clicking a total copies it.
private final class FootingWindow: NSWindow {
    struct Total {
        let text: String
        /// What a click copies.
        let plain: String
        /// Screen x, AppKit coordinates.
        let rightEdge: CGFloat
    }

    fileprivate static let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    private static let padding = CGSize(width: 8, height: 3)

    private let selection: Selection
    private let footingView = FootingView()

    init(selection: Selection) {
        self.selection = selection
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = footingView
    }

    /// Lays the labels out again: totals change width as amounts are left out.
    func show(_ totals: [Total]) {
        let labels = totals.map { total in
            let text = (total.text as NSString).size(withAttributes: [.font: Self.font])
            return FootingPlacement.Label(
                rightEdge: total.rightEdge,
                size: CGSize(width: ceil(text.width) + 2 * Self.padding.width,
                             height: ceil(text.height) + 2 * Self.padding.height))
        }
        let frames = FootingPlacement.frames(
            for: labels, selection: selection.rect, visible: selection.screen.visibleFrame)
        guard let first = frames.first else { return }
        let bounds = frames.dropFirst().reduce(first) { $0.union($1) }

        setFrame(bounds, display: false)
        footingView.labels = zip(totals, frames).map { total, frame in
            FootingView.Label(total: total, frame: frame.offsetBy(dx: -bounds.minX, dy: -bounds.minY))
        }
    }
}

private final class FootingView: NSView {
    struct Label {
        let total: FootingWindow.Total
        /// View coordinates.
        let frame: CGRect
    }

    private static let copiedText = "\u{2713} Copied"
    private static let copiedShortText = "\u{2713}"
    private static let copiedFeedback: TimeInterval = 1.2

    var labels: [Label] = [] {
        didSet {
            copied = nil
            if let hovered, hovered >= labels.count { self.hovered = nil }
            updateTrackingAreas()
            needsDisplay = true
        }
    }
    private var hovered: Int?
    private var copied: Int?
    private var clearCopied: DispatchWorkItem?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Hover and click

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        for (index, label) in labels.enumerated() {
            addTrackingArea(NSTrackingArea(
                rect: label.frame, options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways], owner: self,
                userInfo: ["index": index]))
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = event.trackingArea?.userInfo?["index"] as? Int
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        if hovered == event.trackingArea?.userInfo?["index"] as? Int {
            hovered = nil
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = labels.firstIndex(where: { $0.frame.contains(point) }) else { return }
        Clipboard.copy(labels[index].total.plain)
        showCopied(index)
    }

    private func showCopied(_ index: Int) {
        copied = index
        needsDisplay = true
        clearCopied?.cancel()
        let clear = DispatchWorkItem { [weak self] in
            self?.copied = nil
            self?.needsDisplay = true
        }
        clearCopied = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedFeedback, execute: clear)
    }

    // MARK: Drawing

    /// Green with white text; darker with a white ring on hover; white with green text just after a copy.
    override func draw(_ dirtyRect: NSRect) {
        for (index, label) in labels.enumerated() {
            let isCopied = index == copied
            let isHovered = index == hovered
            let shape = NSBezierPath(roundedRect: label.frame.insetBy(dx: 0.75, dy: 0.75), xRadius: 5, yRadius: 5)

            let fill: NSColor = isCopied ? .white
                : isHovered ? (NSColor.systemGreen.shadow(withLevel: 0.25) ?? .systemGreen) : .systemGreen
            fill.setFill()
            shape.fill()
            if isCopied || isHovered {
                (isCopied ? NSColor.systemGreen : NSColor.white).setStroke()
                shape.lineWidth = 1.5
                shape.stroke()
            }

            let textColor: NSColor = isCopied ? .systemGreen : .white
            drawCentered(isCopied ? copiedText(fitting: label.frame) : label.total.text, in: label.frame, color: textColor)
        }
    }

    private func copiedText(fitting frame: CGRect) -> String {
        let width = (Self.copiedText as NSString).size(withAttributes: [.font: FootingWindow.font]).width
        return width + 8 <= frame.width ? Self.copiedText : Self.copiedShortText
    }

    private func drawCentered(_ text: String, in frame: CGRect, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: FootingWindow.font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2), withAttributes: attributes)
    }
}
