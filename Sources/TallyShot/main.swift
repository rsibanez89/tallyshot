import AppKit

let arguments = CommandLine.arguments
if arguments.count >= 2, arguments[1] == "--analyze" {
    exit(AnalyzeCommand.run(arguments: Array(arguments.dropFirst(2))))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
