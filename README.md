# TallyShot

<img src="Resources/AppIcon/AppIcon-1024.png" width="128" alt="TallyShot icon: selection brackets around tally marks">

Sum & copy tables from screen.
Press a hotkey, drag over numbers or a table, get the total or a spreadsheet-ready copy.
macOS menu bar app, prototype.

## How it works

1. `cmd+shift+6`, or menu bar icon then "Sum a Region".
2. Drag a rectangle. Esc cancels.
3. On release, the region is captured and read with on-device OCR (Apple Vision).
   Each numeric column's total appears in a green label just below the selection, right-aligned under its column.
   Click a total to copy it (plain, `-899.88`); it flashes "✓ Copied".
4. A panel opens beside the selection with three tabs. `1`, `2`, `3` switch; the last tab is remembered.
   - **Sum**: a total for every numeric column. Green boxes mark every amount counted on screen.
     Hover a box and click ✕ to leave it out (it turns gray), or ✓ to bring it back. Totals update live.
     Click a column in the panel to see its values.
     The leftmost numeric column is the default, then the last one you picked (by header name).
   - **Table**: the selection as a grid. Dashed lines on screen show where columns were split.
   - **Text**: the recognised text, one line per row.
5. `cmd+C` runs the tab's main copy.
6. The result stays up until Esc, the panel's close button, or the next capture. Esc works from any app while a result is up.

| Tab | Main copy (`cmd+C`) | Other |
|---|---|---|
| Sum | Selected column's total, plain (`1234.50`) | Its included values, one per line |
| Table | HTML table + tab-separated text: pastes as cells in Sheets, Excel, Numbers, Docs | Markdown, first row as header |
| Text | Plain text | |

Nothing leaves the machine.
Logs hold timings and counts only, never recognised text or amounts.

## Parsing rules

- `,` groups thousands, `.` marks decimals. `1234,56` is rejected, not misread.
- Negative: `-45`, `-$45`, `$-45`, `(45)`, `45-`, `45 DR`, U+2212 minus.
- Ignored: dates, times, percentages, IDs (`INV2045`), digit-hyphen-digit runs.
- Rows: fragments that overlap vertically form one row.
- Columns: split at horizontal gaps crossed by at most one fragment. A single crossing fragment is a spanning cell, such as a title.
- A cell counts as an amount only when its whole text is one amount. "12 of 12 results" and "28 Jun 2026" never count.
- A column is numeric when at least half its non-empty cells, header aside, are amounts. Its header is the nearest text above the first amount.
- Table cells keep the text exactly as read (`$1,954.80`).

Logic lives in `Sources/TallyShotCore`, covered by tests.

## Requirements

- macOS 14+.
- Command Line Tools are enough; Xcode is not needed.
- Screen Recording permission, asked on first launch.

## Commands

```bash
./scripts/test.sh                 # unit tests (TallyShotCore)
./scripts/build-app.sh            # builds dist/TallyShot.app without installing
swift run TallyShot --analyze x.png                 # prints sum, table (Markdown) and text
swift run TallyShot --analyze x.png --copy table    # also writes the clipboard like the panel
log stream --predicate 'subsystem == "local.tallyshot"'
./scripts/make-icon.sh            # regenerates Resources/AppIcon from scripts/render-icon.swift
```

## Install and permissions

```bash
./scripts/setup-signing.sh   # once: local signing certificate, clears stale permission entries
./scripts/install.sh         # every update: build, replace /Applications/TallyShot.app, relaunch
```

- macOS ties Screen Recording to the app's signature.
- Ad-hoc builds get a new signature each time, so macOS asks again after every rebuild.
- `setup-signing.sh` creates "TallyShot Local Signing" in the login keychain. Builds signed with it keep the grant.
- On first use, macOS may ask to let `codesign` use the key: choose "Always Allow".
- Grant Screen Recording once, then quit and reopen TallyShot.
- macOS may still show a periodic "continue to allow screen recording?" reminder. That is system policy, not a lost grant.
- The hotkey uses Carbon `RegisterEventHotKey`: no Accessibility permission.

## Known limits

- English OCR, `.`-decimal formats only.
- One display per selection.
- A description wrapped over two lines becomes two table rows.
- A column with no amounts at all (an empty "Money in") is not listed.
- SwiftUI `@State` is unavailable without Xcode (macro plugin missing). Views use `ObservableObject` instead.
