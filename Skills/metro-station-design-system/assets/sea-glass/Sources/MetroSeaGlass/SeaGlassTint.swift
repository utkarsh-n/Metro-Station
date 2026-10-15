import SwiftUI

/// Pigment families for the custom satin material. Pair every semantic use with a label or symbol.
public enum SeaGlassTint: String, CaseIterable, Identifiable, Sendable {
    case tide, kelp, amber, violet, frost

    public var id: Self { self }

    public var name: String {
        switch self {
        case .tide: "Tide"
        case .kelp: "Kelp"
        case .amber: "Amber"
        case .violet: "Violet"
        case .frost: "Frost"
        }
    }

    public var color: Color {
        switch self {
        case .tide: Color(red: 0.34, green: 0.84, blue: 0.82)
        case .kelp: Color(red: 0.57, green: 0.76, blue: 0.48)
        case .amber: Color(red: 0.94, green: 0.72, blue: 0.39)
        case .violet: Color(red: 0.69, green: 0.59, blue: 0.84)
        case .frost: Color(red: 0.82, green: 0.89, blue: 0.88)
        }
    }

    /// An opaque fallback for Reduce Transparency, tuned independently for each appearance.
    public func opaqueColor(for scheme: ColorScheme) -> Color {
        switch (self, scheme) {
        case (.tide, .dark): Color(red: 0.10, green: 0.24, blue: 0.25)
        case (.kelp, .dark): Color(red: 0.17, green: 0.23, blue: 0.15)
        case (.amber, .dark): Color(red: 0.28, green: 0.21, blue: 0.12)
        case (.violet, .dark): Color(red: 0.22, green: 0.18, blue: 0.29)
        case (.frost, .dark): Color(red: 0.19, green: 0.25, blue: 0.26)
        case (.tide, _): Color(red: 0.78, green: 0.91, blue: 0.88)
        case (.kelp, _): Color(red: 0.85, green: 0.91, blue: 0.77)
        case (.amber, _): Color(red: 0.96, green: 0.88, blue: 0.73)
        case (.violet, _): Color(red: 0.89, green: 0.84, blue: 0.95)
        case (.frost, _): Color(red: 0.91, green: 0.94, blue: 0.92)
        }
    }
}
