import AppKit
import TallyShotCore

/// Every call replaces the general pasteboard's contents.
enum Clipboard {
    @MainActor
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// HTML pastes as cells in Sheets, Excel, Numbers and Docs; tab-separated text covers everything else.
    @MainActor
    static func copyTable(_ table: Table) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(TableExporter.html(table), forType: .html)
        pasteboard.setString(TableExporter.tsv(table), forType: .string)
    }
}
