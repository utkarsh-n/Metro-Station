import SwiftUI

enum LabBackdrop: String, CaseIterable, Identifiable {
    case signal, type, color, grid
    var id: Self { self }
    var title: String {
        switch self {
        case .signal: "Bands"
        case .type: "Type"
        case .color: "Colors"
        case .grid: "Grid"
        }
    }
}

/// Deterministic diagnostic artwork behind the material, never a measured signal.
struct LabBackdropView: View {
    let backdrop: LabBackdrop
    let isMineral: Bool
    var visible = true

    var body: some View {
        Canvas { context, size in
            guard visible else { return }
            let ink = isMineral ? Color.black : Color.white
            let width = Double(size.width)
            let height = Double(size.height)
            switch backdrop {
            case .signal:
                drawGrid(context: &context, size: size, ink: ink.opacity(0.06), spacing: 24)
                for (channel, color) in [Color.cyan, .green, .orange, .purple].enumerated() {
                    var path = Path()
                    for sample in 0...160 {
                        let x = width * Double(sample) / 160
                        let phase = Double(sample) / 23 + Double(channel)
                        let carrier = sin(phase) * height * 0.29
                        let offset = Double(channel - 1) * height * 0.064
                        let y = height * 0.5 + carrier + offset
                        if sample == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(color.opacity(isMineral ? 0.8 : 0.75)), lineWidth: max(8, size.height * 0.055))
                }
            case .type:
                for row in 0..<7 {
                    let word = row.isMultiple(of: 2) ? "SEA GLASS 0123" : "Aa Bb Cc 4567"
                    let label = Text(word)
                        .font(.system(size: max(16, size.width * 0.065), weight: .semibold, design: .monospaced))
                        .foregroundStyle(ink.opacity(row.isMultiple(of: 2) ? 0.8 : 0.3))
                    context.draw(label, at: CGPoint(x: 12, y: size.height * (Double(row) + 0.7) / 7), anchor: .leading)
                }
            case .color:
                let colors: [Color] = [.cyan, .green, .orange, .purple, .pink, .blue]
                for index in colors.indices {
                    let column = Double(index % 3)
                    let row = Double(index / 3)
                    let rect = CGRect(x: size.width * (column / 3 - 0.06), y: size.height * (row / 2 - 0.08),
                                      width: size.width * 0.48, height: size.height * 0.72)
                    context.fill(Path(ellipseIn: rect), with: .color(colors[index].opacity(isMineral ? 0.7 : 0.6)))
                }
            case .grid:
                drawGrid(context: &context, size: size, ink: ink.opacity(0.46), spacing: 16)
                let crosshair = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.5))
                    path.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                    path.move(to: CGPoint(x: size.width * 0.5, y: 0))
                    path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
                }
                context.stroke(crosshair, with: .color(.orange.opacity(0.8)), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize, ink: Color, spacing: Double) {
        var path = Path()
        for x in stride(from: 0.0, through: size.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0.0, through: size.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(ink), lineWidth: 0.7)
    }
}
