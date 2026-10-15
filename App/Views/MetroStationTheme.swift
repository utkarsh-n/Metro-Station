import SwiftUI

enum MetroStationTheme {
    static let background = Color(red: 0.025, green: 0.042, blue: 0.058)
    static let panel = Color(red: 0.045, green: 0.070, blue: 0.087)
    static let cyan = Color(red: 0.34, green: 0.93, blue: 0.96)
    static let amber = Color(red: 1.00, green: 0.74, blue: 0.37)
    static let secondary = Color(red: 0.60, green: 0.69, blue: 0.73)
}

struct InstrumentBackground: View {
    var body: some View {
        ZStack {
            MetroStationTheme.background
            RadialGradient(colors: [MetroStationTheme.cyan.opacity(0.085), .clear],
                           center: .topTrailing, startRadius: 5, endRadius: 620)
            Canvas { context, size in
                var grid = Path()
                for x in stride(from: 0.0, through: size.width, by: 28) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0.0, through: size.height, by: 28) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    func instrumentPanel() -> some View {
        self
            .padding(16)
            .background(MetroStationTheme.panel.opacity(0.85), in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.09), lineWidth: 1))
    }
}
