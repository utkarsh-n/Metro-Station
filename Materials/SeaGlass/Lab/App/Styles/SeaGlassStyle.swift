import Foundation

enum SeaGlassStyleTint: String, CaseIterable, Codable, Identifiable, Sendable {
    case tide, kelp, amber, violet, frost
    var id: Self { self }
    var displayName: String { rawValue.capitalized }
    var canonicalRGB: [Double] {
        switch self {
        case .tide: [0.34, 0.84, 0.82]
        case .kelp: [0.57, 0.76, 0.48]
        case .amber: [0.94, 0.72, 0.39]
        case .violet: [0.69, 0.59, 0.84]
        case .frost: [0.82, 0.89, 0.88]
        }
    }
}

enum SeaGlassStyleAppearance: String, CaseIterable, Codable, Identifiable, Sendable {
    case metro, mineral
    var id: Self { self }
    var displayName: String { rawValue.capitalized }
}

/// A complete artistic recipe; there are no physical optical units in these coefficients.
struct SeaGlassStyle: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String { didSet { name = Self.validName(name) } }
    var notes: String { didSet { notes = String(notes.prefix(10_000)) } }
    var tint: SeaGlassStyleTint
    var appearance: SeaGlassStyleAppearance
    var frost: Double { didSet { frost = Self.bounded(frost, in: 0...1, fallback: 0.64) } }
    var depth: Double { didSet { depth = Self.bounded(depth, in: 0...1, fallback: 0.55) } }
    var grain: Double { didSet { grain = Self.bounded(grain, in: 0...1, fallback: 0.45) } }
    /// Screen-coordinate angle from the right: 90° points down; 225° points upper-left.
    var lightAngleDegrees: Double { didSet { lightAngleDegrees = Self.bounded(lightAngleDegrees, in: 0...360, fallback: 225) } }
    var cornerRadius: Double { didSet { cornerRadius = Self.bounded(cornerRadius, in: 12...64, fallback: 38) } }
    var forceOpaque: Bool
    var staticLight: Bool

    init(
        id: UUID = UUID(), name: String = "Untitled style", notes: String = "",
        tint: SeaGlassStyleTint = .tide, appearance: SeaGlassStyleAppearance = .metro,
        frost: Double = 0.64, depth: Double = 0.55, grain: Double = 0.45,
        lightAngleDegrees: Double = 225, cornerRadius: Double = 38,
        forceOpaque: Bool = false, staticLight: Bool = false
    ) {
        self.id = id
        self.name = Self.validName(name)
        self.notes = String(notes.prefix(10_000))
        self.tint = tint
        self.appearance = appearance
        self.frost = Self.bounded(frost, in: 0...1, fallback: 0.64)
        self.depth = Self.bounded(depth, in: 0...1, fallback: 0.55)
        self.grain = Self.bounded(grain, in: 0...1, fallback: 0.45)
        self.lightAngleDegrees = Self.bounded(lightAngleDegrees, in: 0...360, fallback: 225)
        self.cornerRadius = Self.bounded(cornerRadius, in: 12...64, fallback: 38)
        self.forceOpaque = forceOpaque
        self.staticLight = staticLight
    }

    static let standard = Self(
        id: UUID(uuidString: "4352D7E7-4C69-4F17-A8B1-64336AB64C17")!,
        name: "Standard"
    )

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, tint, appearance, frost, depth, grain
        case lightAngleDegrees, cornerRadius, forceOpaque, staticLight
    }

    /// Missing, wrong-type or unknown-enum fields use deliberate defaults; numbers are clamped.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: (try? values.decode(UUID.self, forKey: .id)) ?? UUID(),
            name: (try? values.decode(String.self, forKey: .name)) ?? "Untitled style",
            notes: (try? values.decode(String.self, forKey: .notes)) ?? "",
            tint: (try? values.decode(SeaGlassStyleTint.self, forKey: .tint)) ?? .tide,
            appearance: (try? values.decode(SeaGlassStyleAppearance.self, forKey: .appearance)) ?? .metro,
            frost: (try? values.decode(Double.self, forKey: .frost)) ?? 0.64,
            depth: (try? values.decode(Double.self, forKey: .depth)) ?? 0.55,
            grain: (try? values.decode(Double.self, forKey: .grain)) ?? 0.45,
            lightAngleDegrees: (try? values.decode(Double.self, forKey: .lightAngleDegrees)) ?? 225,
            cornerRadius: (try? values.decode(Double.self, forKey: .cornerRadius)) ?? 38,
            forceOpaque: (try? values.decode(Bool.self, forKey: .forceOpaque)) ?? false,
            staticLight: (try? values.decode(Bool.self, forKey: .staticLight)) ?? false
        )
    }

    private static func validName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled style" : String(trimmed.prefix(120))
    }

    private static func bounded(_ value: Double, in range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

enum SeaGlassVariantGenerator {
    /// Same base recipe and explicit seed produce the same four recipes and IDs.
    /// Saving a candidate to the library assigns a separate fresh favorite ID.
    static func generate(from base: SeaGlassStyle, seed: UInt64) -> [SeaGlassStyle] {
        var random = SplitMix64(seed: seed)
        return (0..<4).map { index in
            let id = random.uuid()
            let frost = mix(base.frost, random.unit(), weight: 0.42)
            let depth = mix(base.depth, random.unit(), weight: 0.42)
            let grain = mix(base.grain, random.unit(), weight: 0.48)
            let radius = mix(base.cornerRadius, 16 + random.unit() * 44, weight: 0.55)
            let angle = (base.lightAngleDegrees + 40 + random.unit() * 280).truncatingRemainder(dividingBy: 360)
            let baseTintIndex = SeaGlassStyleTint.allCases.firstIndex(of: base.tint) ?? 0
            let tint: SeaGlassStyleTint = index == 0 ? base.tint :
                SeaGlassStyleTint.allCases[(baseTintIndex + 1 + Int(random.next() % 4)) % 5]
            return SeaGlassStyle(
                id: id, name: "Study \(index + 1) · \(tint.displayName)",
                notes: "Generated from \(base.name). Seed \(seed), candidate \(index + 1).",
                tint: tint, appearance: base.appearance,
                frost: frost, depth: depth, grain: grain,
                lightAngleDegrees: angle, cornerRadius: radius,
                forceOpaque: base.forceOpaque, staticLight: base.staticLight
            )
        }
    }

    private static func mix(_ base: Double, _ target: Double, weight: Double) -> Double {
        base * (1 - weight) + target * weight
    }

    private struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
        mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
        mutating func uuid() -> UUID {
            let first = next(), second = next()
            var bytes = (0..<8).map { UInt8(truncatingIfNeeded: first >> (56 - $0 * 8)) }
            bytes += (0..<8).map { UInt8(truncatingIfNeeded: second >> (56 - $0 * 8)) }
            bytes[6] = (bytes[6] & 0x0F) | 0x40
            bytes[8] = (bytes[8] & 0x3F) | 0x80
            return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                               bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        }
    }
}
