import CoreGraphics
import TallyShotCore
import Vision

struct Analysis: Sendable {
    let fragments: [TextFragment]
    let layout: TableLayout
    let columnSums: [ColumnSum]
    /// Parallel to `columnSums`, then to each column's `cells`. Normalised to the image, origin top-left.
    let amountBoxes: [[CGRect]]
}

/// On-device OCR, then table layout and column totals. Nothing leaves the machine.
enum Analyzer {
    static func analyze(_ image: CGImage) async throws -> Analysis {
        try await Task.detached(priority: .userInitiated) { try analyzeBlocking(image) }.value
    }

    static func analyzeBlocking(_ image: CGImage) throws -> Analysis {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction rewrites digit runs it mistakes for words.
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])

        let lines = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { (observation: observation, text: $0) }
        }
        let fragments = lines.map { TextFragment(text: $0.text.string, box: topLeft($0.observation.boundingBox)) }
        let layout = TableBuilder.build(fragments)
        let columnSums = ColumnSummer.sums(layout, fragments: fragments)
        let amountBoxes = columnSums.map { sum in
            sum.cells.map { cell in
                let line = lines[cell.fragmentIndex]
                let tokenBox = (try? line.text.boundingBox(for: cell.amount.range))?.boundingBox
                return topLeft(tokenBox ?? line.observation.boundingBox)
            }
        }
        return Analysis(fragments: fragments, layout: layout, columnSums: columnSums, amountBoxes: amountBoxes)
    }

    /// Vision boxes use a bottom-left origin.
    private static func topLeft(_ box: CGRect) -> CGRect {
        CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }
}
