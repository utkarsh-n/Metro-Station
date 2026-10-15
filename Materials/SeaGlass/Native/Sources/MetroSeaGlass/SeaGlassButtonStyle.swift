import SwiftUI

/// A native Button style with a stable label and a minimum 44 × 44 point hit surface.
/// The host owns domain changes, accepted-event haptics, sounds, and any repeat behavior.
public struct SeaGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let tint: SeaGlassTint
    private let configuration: SeaGlassConfiguration
    private let cornerRadius: CGFloat

    public init(
        tint: SeaGlassTint = .tide,
        configuration: SeaGlassConfiguration = .standard,
        cornerRadius: CGFloat = 24
    ) {
        self.tint = tint
        self.configuration = configuration
        self.cornerRadius = max(0, cornerRadius.isFinite ? cornerRadius : 24)
    }

    public func makeBody(configuration button: Configuration) -> some View {
        var surfaceConfiguration = configuration
        surfaceConfiguration.depth *= button.isPressed ? 0.45 : 1
        return SeaGlassSurface(
            tint: tint,
            configuration: surfaceConfiguration,
            cornerRadius: cornerRadius
        ) {
            button.label
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
