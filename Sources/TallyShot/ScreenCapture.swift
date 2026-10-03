import AppKit
import ScreenCaptureKit

enum CaptureError: Error {
    case permissionDenied
    case displayNotFound
}

/// The parts of an `NSScreen` that capture needs, safe to hand off the main actor.
struct CaptureTarget: Sendable {
    let displayID: CGDirectDisplayID
    /// AppKit global coordinates.
    let screenFrame: CGRect
    let scale: CGFloat

    @MainActor
    init?(screen: NSScreen) {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return nil }
        displayID = id
        screenFrame = screen.frame
        scale = screen.backingScaleFactor
    }
}

enum ScreenCapture {
    /// Captures `rect` (AppKit global coordinates) at native pixel density, excluding this app's own windows.
    static func capture(_ rect: CGRect, on target: CaptureTarget) async throws -> CGImage {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == target.displayID }) else {
                throw CaptureError.displayNotFound
            }
            let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])

            let local = rect.offsetBy(dx: -target.screenFrame.minX, dy: -target.screenFrame.minY)
            let config = SCStreamConfiguration()
            // ScreenCaptureKit uses display-local points with a top-left origin.
            config.sourceRect = CGRect(
                x: local.minX, y: target.screenFrame.height - local.maxY, width: local.width, height: local.height)
            config.width = Int((local.width * target.scale).rounded())
            config.height = Int((local.height * target.scale).rounded())
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch let error as CaptureError {
            throw error
        } catch {
            // ScreenCaptureKit reports a missing grant as several different errors.
            if !CGPreflightScreenCaptureAccess() { throw CaptureError.permissionDenied }
            throw error
        }
    }
}
