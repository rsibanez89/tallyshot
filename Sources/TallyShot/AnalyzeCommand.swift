import Foundation
import ImageIO
import TallyShotCore

/// `TallyShot --analyze <image> [--copy table|markdown|text]`
/// Runs OCR, table layout and column totals on a file and prints what each tab would show.
/// `--copy` also writes the clipboard exactly as the panel's buttons do.
enum AnalyzeCommand {
    enum CopyTarget: String {
        case table, markdown, text
    }

    @MainActor
    static func run(arguments: [String]) -> Int32 {
        guard let imagePath = arguments.first else { return usage() }
        var copyTarget: CopyTarget?
        if arguments.count == 3, arguments[1] == "--copy" {
            guard let target = CopyTarget(rawValue: arguments[2]) else { return usage() }
            copyTarget = target
        } else if arguments.count != 1 {
            return usage()
        }

        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            FileHandle.standardError.write(Data("Cannot read image at \(imagePath)\n".utf8))
            return 1
        }
        let analysis: Analysis
        do {
            analysis = try Analyzer.analyzeBlocking(image)
        } catch {
            FileHandle.standardError.write(Data("Analysis failed: \(error)\n".utf8))
            return 1
        }

        printSum(analysis)
        print("\n== table: \(analysis.layout.table.rows.count) rows x \(analysis.layout.table.columnCount) columns (markdown)")
        print(TableExporter.markdown(analysis.layout.table))
        print("\n== text")
        print(TableExporter.plainText(analysis.layout.table))

        switch copyTarget {
        case .table: Clipboard.copyTable(analysis.layout.table)
        case .markdown: Clipboard.copy(TableExporter.markdown(analysis.layout.table))
        case .text: Clipboard.copy(TableExporter.plainText(analysis.layout.table))
        case nil: break
        }
        if let copyTarget { print("\ncopied \(copyTarget.rawValue) to the clipboard") }
        return 0
    }

    private static func printSum(_ analysis: Analysis) {
        print("== sum: \(analysis.fragments.count) lines read, \(analysis.columnSums.count) numeric column(s)")
        for sum in analysis.columnSums {
            let digits = sum.fractionDigits
            let title = sum.header ?? "Column \(sum.column + 1)"
            print("\(title): \(sum.cells.count) values, total \(AmountFormatter.display(sum.total, fractionDigits: digits))")
            for cell in sum.cells {
                let text = analysis.fragments[cell.fragmentIndex].text
                let value = AmountFormatter.display(cell.amount.value, fractionDigits: digits)
                print("  row \(cell.row + 1): \(value)  <- \"\(text)\"")
            }
        }
    }

    private static func usage() -> Int32 {
        FileHandle.standardError.write(Data("usage: TallyShot --analyze <image> [--copy table|markdown|text]\n".utf8))
        return 2
    }
}
