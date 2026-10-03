// Draws the TallyShot app icon with Core Graphics: selection brackets around tally marks.
// Source of truth for Resources/AppIcon. Run scripts/make-icon.sh rather than this directly.
// Usage: swift scripts/render-icon.swift <size> <out.png>
// Geometry is in 1024 units on Apple's macOS icon grid: an 824 rounded square inset by 100.
import AppKit

let size = Int(CommandLine.arguments[1])!
let outPath = CommandLine.arguments[2]

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let scale = CGFloat(size) / 1024
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: scale, y: -scale)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let white = rgb(0xFFFFFF)

func stroke(_ points: [CGPoint], width: CGFloat) {
    ctx.setStrokeColor(white)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addLines(between: points)
    ctx.strokePath()
}

// Body. Shadow geometry is in device pixels, so it scales by hand.
let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                  cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 24 * scale, color: rgb(0x000000, 0.28))
ctx.addPath(body)
ctx.setFillColor(rgb(0x1E9E4A))
ctx.fillPath()
ctx.restoreGState()

// Green gradient, lighter at the top, with a soft sheen.
ctx.saveGState()
ctx.addPath(body)
ctx.clip()
let fill = CGGradient(colorsSpace: colorSpace, colors: [rgb(0x3DD06B), rgb(0x168A3E)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(fill, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
let sheen = CGGradient(
    colorsSpace: colorSpace, colors: [rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 480), options: [])
ctx.restoreGState()

// Selection brackets.
let frame = CGRect(x: 220, y: 220, width: 584, height: 584)
let arm: CGFloat = 120
let bracketWidth: CGFloat = 46
stroke([CGPoint(x: frame.minX, y: frame.minY + arm), CGPoint(x: frame.minX, y: frame.minY),
        CGPoint(x: frame.minX + arm, y: frame.minY)], width: bracketWidth)
stroke([CGPoint(x: frame.maxX - arm, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.minY + arm)], width: bracketWidth)
stroke([CGPoint(x: frame.minX, y: frame.maxY - arm), CGPoint(x: frame.minX, y: frame.maxY),
        CGPoint(x: frame.minX + arm, y: frame.maxY)], width: bracketWidth)
stroke([CGPoint(x: frame.maxX - arm, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY),
        CGPoint(x: frame.maxX, y: frame.maxY - arm)], width: bracketWidth)

// Tally marks: four strokes and a slash.
let top: CGFloat = 360
let bottom: CGFloat = 664
let spacing: CGFloat = 78
let markWidth: CGFloat = 46
let xs = (0..<4).map { 512 + (CGFloat($0) - 1.5) * spacing }
for x in xs {
    stroke([CGPoint(x: x, y: top), CGPoint(x: x, y: bottom)], width: markWidth)
}
let overhang = spacing * 0.75
let slashInset = (bottom - top) * 0.22
stroke([CGPoint(x: xs[0] - overhang, y: bottom - slashInset), CGPoint(x: xs[3] + overhang, y: top + slashInset)],
       width: markWidth)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
