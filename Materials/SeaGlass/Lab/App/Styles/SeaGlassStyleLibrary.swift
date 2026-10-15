import Foundation
import Observation

@Observable
@MainActor
final class SeaGlassStyleLibrary {
    private(set) var styles: [SeaGlassStyle] = []
    private(set) var error: String?
    let stylesURL: URL

    init(stylesURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.stylesURL = stylesURL ?? documents.appendingPathComponent("Styles/styles.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: stylesURL.path) else {
            styles = []
            error = nil
            return
        }
        do {
            let archive = try JSONDecoder().decode(StyleArchive.self, from: Data(contentsOf: stylesURL))
            guard archive.version == 1 else { throw LibraryError.unsupportedVersion(archive.version) }
            // Preserve the first identity if a hand-edited archive repeats a favorite ID.
            var seen = Set<UUID>()
            styles = archive.styles.filter { seen.insert($0.id).inserted }
            error = nil
        } catch {
            self.error = "Couldn't load styles: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveSnapshot(of style: SeaGlassStyle, name: String, notes: String) -> SeaGlassStyle? {
        var snapshot = style
        snapshot.id = UUID()
        snapshot.name = name
        snapshot.notes = notes
        let next = [snapshot] + styles
        guard persist(next) else { return nil }
        styles = next
        return snapshot
    }

    @discardableResult
    func delete(id: UUID) -> Bool {
        let next = styles.filter { $0.id != id }
        guard next.count != styles.count else { return false }
        guard persist(next) else { return false }
        styles = next
        return true
    }

    private func persist(_ styles: [SeaGlassStyle]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(StyleArchive(version: 1, styles: styles))
            try FileManager.default.createDirectory(at: stylesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: stylesURL, options: .atomic)
            error = nil
            return true
        } catch {
            self.error = "Couldn't save styles: \(error.localizedDescription)"
            return false
        }
    }

    private struct StyleArchive: Codable {
        var version: Int
        var styles: [SeaGlassStyle]
    }

    private enum LibraryError: LocalizedError {
        case unsupportedVersion(Int)
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version): "Unsupported style library version \(version)."
            }
        }
    }
}
