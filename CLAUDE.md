# CLAUDE.md

Rules for agents working on TallyShot.
Read `README.md` first.

## Where things live

- `Sources/TallyShotCore/`: pure logic, no AppKit or Vision. Parsing, row and column grouping, column totals, table export, formatting, panel and footing placement.
- `Sources/TallyShot/`: the app.
  - `SumFlow.swift`: orchestrates select, capture, OCR, sum and table, show.
  - `SelectionOverlay.swift`: crosshair and green dashed drag rectangle.
  - `ScreenCapture.swift`: ScreenCaptureKit region capture, excludes own windows.
  - `Analyzer.swift`: Vision OCR, then `TableBuilder` and `ColumnSummer`.
  - `ResultModel.swift`, `ResultView.swift`, `ResultPresenter.swift`: tabbed result panel, highlight, on-screen column totals.
  - `Clipboard.swift`: all pasteboard writes.
  - `AnalyzeCommand.swift`: `--analyze <image> [--copy ...]` debug CLI.
- `scripts/`: `build-app.sh`, `make-dmg.sh`, `install.sh` (local), `ci-import-certificate.sh` (release), `setup-signing.sh` / `setup-release-signing.sh` (one-time).
- `.github/workflows/release.yml`: tag `v*` publishes `TallyShot.dmg` to GitHub Releases. `docs/`: landing page (GitHub Pages).

## Hard rules

- New parsing or grouping behaviour goes in `TallyShotCore` with tests.
- Never log recognised text or amounts. Bank data. Timings and counts only.
- No network calls.
- Build with Command Line Tools: no Swift macros (`@State`, `@Observable`, XCTest). `ObservableObject` works. Swift Testing works via `scripts/test.sh`.
- Verify OCR changes with `--analyze` on a rendered image, not only unit tests.
- The icon is drawn in code: edit `scripts/render-icon.swift`, then run `scripts/make-icon.sh`. Never edit `Resources/AppIcon/` by hand.
- Do not run `build-app.sh` or `install.sh`: they sign with Rodrigo's keychain key and trigger a password prompt. Verify with `swift build`, `scripts/test.sh`, `--analyze`.
