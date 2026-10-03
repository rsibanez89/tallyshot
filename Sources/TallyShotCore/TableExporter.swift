/// Cell text is kept exactly as read, so "$1,954.80" stays "$1,954.80".
public enum TableExporter {
    /// Tab-separated. Spreadsheets split it into cells on paste.
    public static func tsv(_ table: Table) -> String {
        table.rows
            .map { row in row.map { singleLine($0).replacingOccurrences(of: "\t", with: " ") }.joined(separator: "\t") }
            .joined(separator: "\n")
    }

    /// Google Sheets, Excel, Numbers and Docs paste this as real cells.
    public static func html(_ table: Table) -> String {
        let rows = table.rows.map { row in
            "<tr>" + row.map { "<td>\(escapeHTML(singleLine($0)))</td>" }.joined() + "</tr>"
        }
        return "<meta charset=\"utf-8\"><table>" + rows.joined() + "</table>"
    }

    /// GitHub-flavoured. The first row becomes the header.
    public static func markdown(_ table: Table) -> String {
        guard let header = table.rows.first else { return "" }
        let line = { (cells: [String]) in
            "| " + cells.map { singleLine($0).replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |"
        }
        let separator = "|" + String(repeating: " --- |", count: header.count)
        return ([line(header), separator] + table.rows.dropFirst().map(line)).joined(separator: "\n")
    }

    /// One line per row, cells separated by a space.
    public static func plainText(_ table: Table) -> String {
        table.rows
            .map { $0.filter { !$0.isEmpty }.joined(separator: " ") }
            .joined(separator: "\n")
    }

    private static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ")
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
