import AppKit

struct Selection {
    /// AppKit global coordinates: origin at the bottom-left of the primary display.
    let rect: CGRect
    let screen: NSScreen
}

/// Full-screen crosshair overlay. Drag draws a green dashed rectangle; Esc or a click without a drag cancels.
@MainActor
final class SelectionOverlay {
    private var windows: [OverlayWindow] = []
    private var completion: (@MainActor (Selection?) -> Void)?

    func begin(completion: @escaping @MainActor (Selection?) -> Void) {
        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.selectionView.onFinish = { [weak self] rect in
                self?.finish(rect.map { Selection(rect: $0, screen: screen) })
            }
            return window
        }
        NSApp.activate()
        windows.forEach { $0.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKey()
        NSCursor.crosshair.push()
    }

    private func finish(_ selection: Selection?) {
        guard let completion else { return }
        self.completion = nil
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        completion(selection)
    }
}

private final class OverlayWindow: NSWindow {
    let selectionView = SelectionView()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = selectionView
        setFrame(screen.frame, display: false)
        initialFirstResponder = selectionView
    }

    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    /// Global screen rect, or nil when cancelled.
    var onFinish: ((CGRect?) -> Void)?
    private var anchor: NSPoint?
    private var current: NSRect?
    private let minimumSide: CGFloat = 4

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        anchor = convert(event.locationInWindow, from: nil)
        current = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        let point = convert(event.locationInWindow, from: nil)
        current = NSRect(
            x: min(anchor.x, point.x), y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x), height: abs(point.y - anchor.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let current, current.width >= minimumSide, current.height >= minimumSide, let window else {
            onFinish?(nil)
            return
        }
        onFinish?(window.convertToScreen(convert(current, to: nil)))
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish?(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.15).setFill()
        bounds.fill()
        guard let current else { return }

        NSColor.clear.setFill()
        current.fill(using: .copy)

        let outline = NSBezierPath(rect: current.insetBy(dx: 1, dy: 1))
        outline.lineWidth = 2
        outline.setLineDash([6, 4], count: 2, phase: 0)
        NSColor.systemGreen.setStroke()
        outline.stroke()
    }
}
