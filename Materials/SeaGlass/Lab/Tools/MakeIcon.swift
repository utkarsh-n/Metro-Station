import AppKit

let side = 1024
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(red: r, green: g, blue: b, alpha: a).cgColor
}
context.setFillColor(color(0.025, 0.042, 0.058))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
let ambient = CGGradient(colorsSpace: space, colors: [color(0.055, 0.15, 0.17), color(0.025, 0.042, 0.058)] as CFArray, locations: [0, 1])!
context.drawRadialGradient(ambient, startCenter: CGPoint(x: 770, y: 810), startRadius: 20,
                           endCenter: CGPoint(x: 600, y: 650), endRadius: 950, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
context.setStrokeColor(color(0.6, 0.9, 0.88, 0.035))
context.setLineWidth(1)
for n in stride(from: 0, through: side, by: 64) {
    context.move(to: CGPoint(x: n, y: 0)); context.addLine(to: CGPoint(x: n, y: side))
    context.move(to: CGPoint(x: 0, y: n)); context.addLine(to: CGPoint(x: side, y: n))
}
context.strokePath()

let pebble = CGMutablePath()
pebble.move(to: CGPoint(x: 252, y: 332))
pebble.addCurve(to: CGPoint(x: 206, y: 525), control1: CGPoint(x: 195, y: 375), control2: CGPoint(x: 172, y: 459))
pebble.addCurve(to: CGPoint(x: 393, y: 783), control1: CGPoint(x: 258, y: 676), control2: CGPoint(x: 314, y: 749))
pebble.addCurve(to: CGPoint(x: 678, y: 790), control1: CGPoint(x: 501, y: 834), control2: CGPoint(x: 605, y: 827))
pebble.addCurve(to: CGPoint(x: 824, y: 555), control1: CGPoint(x: 771, y: 748), control2: CGPoint(x: 853, y: 660))
pebble.addCurve(to: CGPoint(x: 662, y: 266), control1: CGPoint(x: 805, y: 406), control2: CGPoint(x: 755, y: 309))
pebble.addCurve(to: CGPoint(x: 252, y: 332), control1: CGPoint(x: 555, y: 199), control2: CGPoint(x: 342, y: 243))
pebble.closeSubpath()
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -22), blur: 38, color: color(0, 0, 0, 0.65))
context.setFillColor(color(0.13, 0.42, 0.40))
context.addPath(pebble); context.fillPath()
context.restoreGState()
context.saveGState()
context.addPath(pebble); context.clip()
let body = CGGradient(colorsSpace: space,
                      colors: [color(0.77, 0.92, 0.83), color(0.46, 0.78, 0.68), color(0.17, 0.54, 0.52)] as CFArray,
                      locations: [0, 0.47, 1])!
context.drawLinearGradient(body, start: CGPoint(x: 305, y: 795), end: CGPoint(x: 747, y: 249), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
let frost = CGGradient(colorsSpace: space, colors: [color(0.9, 1, 0.95, 0.20), color(0.9, 1, 0.95, 0)] as CFArray, locations: [0, 1])!
context.drawRadialGradient(frost, startCenter: CGPoint(x: 460, y: 578), startRadius: 20,
                           endCenter: CGPoint(x: 460, y: 578), endRadius: 360, options: [.drawsBeforeStartLocation])
var seed: UInt64 = 0x5EA61A55
func random() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double(seed >> 32) / Double(UInt32.max)
}
for index in 0..<12_000 {
    let x = random() * 1024, y = random() * 1024, diameter = 0.8 + random() * 1.6
    context.setFillColor(index.isMultiple(of: 4) ? color(0.04, 0.28, 0.26, 0.055) : color(0.97, 1, 0.97, 0.12))
    context.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
}
context.restoreGState()
context.addPath(pebble)
context.setStrokeColor(color(0.12, 0.46, 0.44, 0.5))
context.setLineWidth(11)
context.strokePath()
context.addPath(pebble)
let rim = CGGradient(colorsSpace: space, colors: [color(0.93, 1, 0.93, 0.72), color(0.59, 0.93, 0.84, 0.04)] as CFArray, locations: [0, 1])!
context.replacePathWithStrokedPath()
context.saveGState(); context.clip()
context.drawLinearGradient(rim, start: CGPoint(x: 300, y: 850), end: CGPoint(x: 730, y: 220), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
context.restoreGState()

let image = NSBitmapImageRep(cgImage: context.makeImage()!)
try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
