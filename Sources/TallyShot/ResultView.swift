import SwiftUI
import TallyShotCore

enum PanelContent {
    case result(ResultModel)
    case message(PanelMessage)
}

enum PanelMessage {
    case noText
    case permissionDenied
    case failed(String)
}

// Views hold no @State: SwiftUI's state macros need Xcode, which this project does not require.

struct ResultView: View {
    let content: PanelContent

    var body: some View {
        switch content {
        case .result(let model):
            ResultTabsView(model: model).padding(12).frame(width: 380)
        case .message(let message):
            MessageView(message: message).padding(12).frame(width: 240)
        }
    }
}

private struct ResultTabsView: View {
    @ObservedObject var model: ResultModel
    private let bodyHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $model.tab) {
                ForEach(ResultTab.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .background { tabShortcuts }

            switch model.tab {
            case .sum: sumTab
            case .table: tableTab
            case .text: textTab
            }
        }
    }

    /// 1, 2, 3 switch tabs.
    private var tabShortcuts: some View {
        ForEach(ResultTab.allCases, id: \.self) { tab in
            Button("") { model.tab = tab }
                .keyboardShortcut(KeyEquivalent(Character("\(tab.rawValue + 1)")), modifiers: [])
                .opacity(0)
        }
    }

    // MARK: Sum

    @ViewBuilder private var sumTab: some View {
        if let selected = model.selected {
            let column = model.selectedColumn
            VStack(spacing: 8) {
                if model.columns.count > 1 { columnPicker }
                ScrollView { values(of: selected, column: column) }
            }
            .frame(height: bodyHeight)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(selected.title).bold().lineLimit(1)
                Spacer()
                Text(model.total(ofColumn: column))
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            }
            HStack {
                copyButton("Copy total", primary: true) { Clipboard.copy(model.plainTotal(ofColumn: column)) }
                copyButton("Copy values") { Clipboard.copy(model.plainValues(ofColumn: column)) }
            }
        } else {
            Text("No numbers found in this selection.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: bodyHeight)
        }
    }

    /// Every numeric column with its total. Clicking one selects it.
    private var columnPicker: some View {
        VStack(spacing: 2) {
            ForEach(Array(model.columns.enumerated()), id: \.offset) { index, column in
                Button {
                    model.selectedColumn = index
                } label: {
                    HStack {
                        Text(column.title).lineLimit(1)
                        Spacer()
                        Text(model.total(ofColumn: index)).monospacedDigit()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(index == model.selectedColumn ? Color.green.opacity(0.2) : Color.clear))
                }
                .buttonStyle(.plain)
            }
            Divider()
        }
    }

    /// Values left out on screen show struck through.
    private func values(of summary: ColumnSummary, column: Int) -> some View {
        VStack(spacing: 2) {
            ForEach(Array(summary.values.enumerated()), id: \.offset) { index, value in
                let isExcluded = model.isExcluded(CellRef(column: column, cell: index))
                HStack {
                    Text("\(index + 1)").foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                        .monospacedDigit()
                        .strikethrough(isExcluded)
                        .foregroundStyle(isExcluded ? .secondary : .primary)
                }
            }
        }
    }

    // MARK: Table

    @ViewBuilder private var tableTab: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                ForEach(Array(model.table.rows.enumerated()), id: \.offset) { index, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .fontWeight(index == 0 ? .semibold : .regular)
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: bodyHeight)
        Text("\(model.table.rows.count) rows × \(model.table.columnCount) columns. First row is the header in Markdown.")
            .font(.caption)
            .foregroundStyle(.secondary)
        HStack {
            copyButton("Copy table", primary: true) { Clipboard.copyTable(model.table) }
            copyButton("Copy as Markdown") { Clipboard.copy(TableExporter.markdown(model.table)) }
        }
    }

    // MARK: Text

    @ViewBuilder private var textTab: some View {
        ScrollView {
            Text(model.plainText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: bodyHeight)
        HStack {
            copyButton("Copy text", primary: true) { Clipboard.copy(model.plainText) }
        }
    }

    /// The primary button answers cmd+C. The last button used reads "Copied".
    @ViewBuilder
    private func copyButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        let button = Button(model.lastCopied == title ? "Copied" : title) {
            model.copy(title, action)
        }
        if primary {
            button.keyboardShortcut("c", modifiers: .command)
        } else {
            button
        }
    }
}

private struct MessageView: View {
    let message: PanelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch message {
            case .noText:
                Text("No text found").bold()
                Text("Nothing readable in the selection.")
                    .font(.caption).foregroundStyle(.secondary)
            case .permissionDenied:
                Text("Screen Recording is off").bold()
                Text("Allow TallyShot in System Settings, then quit and reopen it.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") { SystemSettings.openScreenRecording() }
            case .failed(let detail):
                Text("Something went wrong").bold()
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
