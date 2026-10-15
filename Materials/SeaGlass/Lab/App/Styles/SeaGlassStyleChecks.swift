#if SEAGLASS_STYLE_CHECKS
import Foundation

/// Standalone Foundation checks; excluded from the application build.
@main
struct SeaGlassStyleChecks {
    @MainActor
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
            guard try condition() else { throw CheckFailure(message: message) }
            checks += 1
        }

        let directory = URL(fileURLWithPath: "/tmp/sea-glass-style-checks", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let hostileText = "Quote \"; slash \\; interpolation \\(fatalError(\"injected\"));\nnew line\tand tab\u{0}"
        var original = SeaGlassStyle(
            name: "Named \"Tide\"", notes: hostileText, tint: .violet, appearance: .mineral,
            frost: 0.12345678901234567, depth: 0.8765432109876543, grain: 0.246810121416182,
            lightAngleDegrees: 359.125, cornerRadius: 41.375, forceOpaque: true, staticLight: true
        )
        let roundtrip = try JSONDecoder().decode(SeaGlassStyle.self, from: JSONEncoder().encode(original))
        try expect(roundtrip == original, "Codable recipe roundtrip changed exact values or strings")

        let malformed = Data("""
        {"id":"invalid", "name":"  ", "tint":"unknown", "appearance":true,
         "frost":4, "depth":-1, "grain":"bad", "lightAngleDegrees":900, "cornerRadius":null}
        """.utf8)
        let decoded = try JSONDecoder().decode(SeaGlassStyle.self, from: malformed)
        try expect(decoded.name == "Untitled style" && decoded.tint == .tide && decoded.appearance == .metro,
                   "Malformed decoded names/enums did not use valid defaults")
        try expect(decoded.frost == 1 && decoded.depth == 0 && decoded.grain == 0.45 && decoded.lightAngleDegrees == 360 && decoded.cornerRadius == 38,
                   "Malformed decoded numbers were not bounded or defaulted")
        original.frost = .nan
        original.depth = -99
        original.grain = .infinity
        original.cornerRadius = 999
        try expect(original.frost == 0.64 && original.depth == 0 && original.grain == 0.45 && original.cornerRadius == 64,
                   "Subsequent mutation bypassed recipe validation")

        let generated = SeaGlassVariantGenerator.generate(from: roundtrip, seed: 42)
        try expect(generated == SeaGlassVariantGenerator.generate(from: roundtrip, seed: 42), "Explicit seed is not deterministic")
        try expect(generated != SeaGlassVariantGenerator.generate(from: roundtrip, seed: 43), "Different seeds produced identical studies")
        for seed: UInt64 in 0..<100 {
            let candidates = SeaGlassVariantGenerator.generate(from: roundtrip, seed: seed)
            try expect(candidates.count == 4 && Set(candidates.map(\.id)).count == 4 && !candidates.contains(where: { $0.id == roundtrip.id }),
                       "Generated study identities are not distinct from the base")
            try expect(Set(candidates.map(\.tint)).count > 1, "Generator did not include a tint alternative")
            try expect(candidates.allSatisfy {
                (0...1).contains($0.frost) && (0...1).contains($0.depth) && (0...1).contains($0.grain)
                && (0...360).contains($0.lightAngleDegrees) && (12...64).contains($0.cornerRadius)
                && $0.appearance == roundtrip.appearance && $0.forceOpaque == roundtrip.forceOpaque && $0.staticLight == roundtrip.staticLight
            }, "Generated study exceeded bounds or lost accommodation/appearance settings")
        }

        let stylesURL = directory.appendingPathComponent("Library-\(UUID().uuidString)/styles.json")
        let library = SeaGlassStyleLibrary(stylesURL: stylesURL)
        guard let favorite = library.saveSnapshot(of: roundtrip, name: "My coast", notes: hostileText) else {
            throw CheckFailure(message: library.error ?? "Saving favorite failed")
        }
        try expect(favorite.id != roundtrip.id && favorite.name == "My coast" && favorite.notes == hostileText, "Favorite is not a named fresh snapshot")
        let reloaded = SeaGlassStyleLibrary(stylesURL: stylesURL)
        try expect(reloaded.styles == [favorite] && reloaded.error == nil, "Atomic persisted favorite did not reload exactly")
        try expect(reloaded.delete(id: favorite.id), "Deleting a persisted favorite failed")
        try expect(SeaGlassStyleLibrary(stylesURL: stylesURL).styles.isEmpty, "Favorite deletion did not persist")
        _ = library.saveSnapshot(of: roundtrip, name: "Keep on read error", notes: "")
        let beforeCorruption = library.styles
        try Data("invalid archive".utf8).write(to: stylesURL, options: .atomic)
        library.load()
        try expect(library.error != nil && library.styles == beforeCorruption, "Failed load erased in-memory favorites")
        let blocker = directory.appendingPathComponent("Blocker-\(UUID().uuidString)")
        try Data("not a directory".utf8).write(to: blocker)
        let blockedLibrary = SeaGlassStyleLibrary(stylesURL: blocker.appendingPathComponent("styles.json"))
        try expect(blockedLibrary.saveSnapshot(of: roundtrip, name: "Cannot save", notes: "") == nil && blockedLibrary.styles.isEmpty && blockedLibrary.error != nil,
                   "Failed persistence published an unsaved favorite")

        let exportData = try SeaGlassStyleExporter.jsonData(styles: [roundtrip], exportedAt: Date(timeIntervalSince1970: 0))
        let envelope = try JSONSerialization.jsonObject(with: exportData) as! [String: Any]
        let recipesData = try JSONSerialization.data(withJSONObject: envelope["styles"]!)
        try expect(try JSONDecoder().decode([SeaGlassStyle].self, from: recipesData) == [roundtrip], "Exported JSON lost recipe values")
        try expect((envelope["version"] as? Int) == 1 && (envelope["tintCanonicalRGB"] as? [String: [Double]])?.count == 5,
                   "Export version or canonical tint metadata is missing")
        let swift = SeaGlassStyleExporter.swiftSource(styles: [roundtrip])
        try expect((envelope["swiftSource"] as? String) == swift, "JSON and Swift exports differ")
        try expect(swift.contains("\\\\(fatalError") && swift.contains("\\u{0}") && swift.contains("\\nnew line\\tand tab"),
                   "Swift string literals did not escape interpolation, control bytes and multiline text")
        try expect(swift.contains("lightAngleDegrees: 359.125, cornerRadius: 41.375") && swift.contains("forceOpaque: true, staticLight: true"),
                   "Swift definitions dropped exact dimensions or accommodation flags")
        let files = try SeaGlassStyleExporter.exportFiles(styles: [roundtrip], directory: directory)
        try expect(try String(contentsOf: files.swiftURL, encoding: .utf8) == swift, "Written Swift export differs")
        try expect(FileManager.default.fileExists(atPath: files.jsonURL.path), "JSON share file is missing")
        let emptySwift = SeaGlassStyleExporter.swiftSource(styles: [])
        try expect(emptySwift.contains("public static let all: [Recipe] = []"), "Empty export is not valid reusable source")
        try Data(emptySwift.utf8).write(to: directory.appendingPathComponent("EmptySavedStyles.swift"), options: .atomic)
        print("Sea Glass style checks passed: \(checks). Exported source: \(files.swiftURL.path)")
    }

    private struct CheckFailure: Error { let message: String }
}
#endif
