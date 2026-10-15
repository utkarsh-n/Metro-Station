import Foundation

/// Familiar practice ranges, not universal definitions; composers and periods vary.
public enum TempoMarking: String, CaseIterable, Codable, Sendable {
    case largo = "Largo"
    case adagio = "Adagio"
    case andante = "Andante"
    case moderato = "Moderato"
    case allegro = "Allegro"
    case presto = "Presto"
    case prestissimo = "Prestissimo"

    public var name: String { rawValue }

    public var character: String {
        switch self {
        case .largo: "Broad and unhurried"
        case .adagio: "Slow and measured"
        case .andante: "At a walking pace"
        case .moderato: "At a moderate pace"
        case .allegro: "Lively and quick"
        case .presto: "Very fast"
        case .prestissimo: "Extremely fast"
        }
    }

    public var approximateRange: ClosedRange<Double> {
        switch self {
        case .largo: 30...60
        case .adagio: 60...76
        case .andante: 76...108
        case .moderato: 108...120
        case .allegro: 120...168
        case .presto: 168...200
        case .prestissimo: 200...240
        }
    }

    public var approximateRangeText: String {
        "\(Int(approximateRange.lowerBound))–\(Int(approximateRange.upperBound)) BPM · approximate"
    }

    public static func forBPM(_ bpm: Double) -> Self {
        let tempo = bpm.isFinite ? min(240, max(30, bpm)) : 120
        return switch tempo {
        case ..<60: .largo
        case ..<76: .adagio
        case ..<108: .andante
        case ..<120: .moderato
        case ..<168: .allegro
        case ..<200: .presto
        default: .prestissimo
        }
    }
}
