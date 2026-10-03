import AppKit
import Carbon.HIToolbox
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let flow = SumFlow()
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private let log = Logger(subsystem: "local.tallyshot", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hotKeyAvailable = registerHotKey()
        statusItem = makeStatusItem(hotKeyAvailable: hotKeyAvailable)
        if !CGPreflightScreenCaptureAccess() {
            log.notice("screen recording not granted, requesting")
            CGRequestScreenCaptureAccess()
        }
    }

    private func registerHotKey() -> Bool {
        do {
            hotKey = try HotKey(keyCode: UInt32(kVK_ANSI_6), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
                self?.flow.start()
            }
            log.info("hotkey registered")
            return true
        } catch {
            log.error("hotkey registration failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private func makeStatusItem(hotKeyAvailable: Bool) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sum", accessibilityDescription: "TallyShot")

        let menu = NSMenu()
        let sum = NSMenuItem(
            title: hotKeyAvailable ? "Sum a Region" : "Sum a Region (hotkey unavailable)",
            action: #selector(startFromMenu), keyEquivalent: hotKeyAvailable ? "6" : "")
        sum.keyEquivalentModifierMask = [.command, .shift]
        sum.target = self
        menu.addItem(sum)

        let settings = NSMenuItem(
            title: "Screen Recording Settings…", action: #selector(openScreenRecordingSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TallyShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        return item
    }

    @objc private func startFromMenu() {
        flow.start()
    }

    @objc private func openScreenRecordingSettings() {
        SystemSettings.openScreenRecording()
    }
}

enum SystemSettings {
    @MainActor
    static func openScreenRecording() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
