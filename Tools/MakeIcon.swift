import AppKit

let size: CGFloat = 1024
let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: Int(size) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(NSColor(red: 0.018, green: 0.038, blue: 0.055, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
let center = CGPoint(x: 512, y: 512)
let colors = [NSColor(red: 0.11, green: 0.17, blue: 0.20, alpha: 1).cgColor,
              NSColor(red: 0.022, green: 0.045, blue: 0.063, alpha: 1).cgColor] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 360, y: 670), startRadius: 0, endCenter: center, endRadius: 520, options: [.drawsAfterEndLocation])
context.setStrokeColor(NSColor.white.withAlphaComponent(0.30).cgColor)
context.setLineWidth(3)
context.strokeEllipse(in: CGRect(x: 103, y: 103, width: 818, height: 818))
func point(_ angle: Double, _ radius: Double) -> CGPoint {
    CGPoint(x: 512 + cos(angle) * radius, y: 512 + sin(angle) * radius)
}
for index in 0...90 {
    let a = Double.pi * 7 / 6 - Double(index) / 90 * Double.pi * 5 / 3
    let major = index % 10 == 0
    let color = NSColor(calibratedHue: 0.50 + CGFloat(index) / 90 * 0.28, saturation: 0.65, brightness: 0.97, alpha: 1)
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(major ? 5 : 2)
    context.move(to: point(a, major ? 333 : 349))
    context.addLine(to: point(a, 370))
    context.strokePath()
}
context.setStrokeColor(NSColor(red: 0.35, green: 0.94, blue: 0.97, alpha: 0.28).cgColor)
context.setLineWidth(2)
context.strokeEllipse(in: CGRect(x: 234, y: 234, width: 556, height: 556))
// A single finite oscillation trace within the calibrated instrument rim.
context.setStrokeColor(NSColor(red: 0.42, green: 0.97, blue: 0.98, alpha: 1).cgColor)
context.setLineWidth(9)
context.setLineJoin(.round)
for index in 0...480 {
    let t = Double(index) / 480
    let envelope = sin(Double.pi * t) * exp(-1.8 * t)
    let y = 512 + sin(t * 10 * Double.pi) * envelope * 200
    let p = CGPoint(x: 262 + 500 * t, y: y)
    if index == 0 { context.move(to: p) } else { context.addLine(to: p) }
}
context.strokePath()
let markAngle = Double.pi * 0.60
context.setStrokeColor(NSColor(red: 1, green: 0.75, blue: 0.36, alpha: 1).cgColor)
context.setLineWidth(9)
context.move(to: point(markAngle, 321))
context.addLine(to: point(markAngle, 385))
context.strokePath()
context.setFillColor(NSColor(red: 1, green: 0.75, blue: 0.36, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 505, y: 783, width: 14, height: 14))
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let target = CommandLine.arguments[1]
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: target))
