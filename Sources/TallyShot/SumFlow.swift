import AppKit
import os

/// Hotkey to result: select, capture, recognise, sum and lay out, show.
@MainActor
final class SumFlow {
    private let overlay = SelectionOverlay()
    private let presenter = ResultPresenter()
    private var isRunning = false
    // Logs timings and counts only. Recognised text and amounts are never logged.
    private let log = Logger(subsystem: "local.tallyshot", category: "flow")

    func start() {
        guard !isRunning else { return }
        isRunning = true
        presenter.dismiss()
        overlay.begin { [weak self] selection in
            guard let self else { return }
            guard let selection else {
                isRunning = false
                return
            }
            Task {
                await self.process(selection)
                self.isRunning = false
            }
        }
    }

    private func process(_ selection: Selection) async {
        let clock = ContinuousClock()
        let started = clock.now
        do {
            guard let target = CaptureTarget(screen: selection.screen) else { throw CaptureError.displayNotFound }
            let image = try await ScreenCapture.capture(selection.rect, on: target)
            let captured = clock.now
            let analysis = try await Analyzer.analyze(image)
            let analysed = clock.now

            log.info("""
                capture \(Self.ms(captured - started), privacy: .public)ms \
                ocr \(Self.ms(analysed - captured), privacy: .public)ms \
                lines \(analysis.fragments.count, privacy: .public) \
                rows \(analysis.layout.table.rows.count, privacy: .public) \
                columns \(analysis.layout.table.columnCount, privacy: .public) \
                numeric-columns \(analysis.columnSums.count, privacy: .public)
                """)

            if analysis.fragments.isEmpty {
                presenter.show(.message(.noText), selection: selection)
            } else {
                presenter.show(.result(ResultModel(analysis)), selection: selection, analysis: analysis)
            }
        } catch CaptureError.permissionDenied {
            log.notice("capture blocked: screen recording not granted")
            presenter.show(.message(.permissionDenied), selection: selection)
        } catch {
            log.error("pipeline failed: \(String(describing: error), privacy: .public)")
            presenter.show(.message(.failed(error.localizedDescription)), selection: selection)
        }
    }

    private static func ms(_ duration: Duration) -> Int {
        Int(duration / .milliseconds(1))
    }
}
