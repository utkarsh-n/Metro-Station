import Foundation

@main
struct ExportPhoneStyles {
    static func main() {
        do {
            guard CommandLine.arguments.count == 3 else {
                throw ExportError.message("Usage: export-phone-styles.sh INPUT_STYLES_JSON OUTPUT_DIRECTORY")
            }
            let input = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
            let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).standardizedFileURL
            let data = try Data(contentsOf: input)
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            guard archive.version == 1 else {
                throw ExportError.message("Unsupported favorite archive version \(archive.version); this tool expects version 1.")
            }
            guard !archive.styles.isEmpty else {
                throw ExportError.message("No saved favorites were found. Save a named style in Sea Glass Lab on your iPhone, then copy Documents/Styles/styles.json again. No exports were written.")
            }
            guard Set(archive.styles.map(\.id)).count == archive.styles.count else {
                throw ExportError.message("The archive repeats a style identity. No exports were written.")
            }
            // The app model deliberately normalizes malformed values. A preference export must
            // refuse that normalization so saved names, notes, identities and values stay exact.
            let source = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let sourceStyles = source?["styles"] as? [[String: Any]], sourceStyles.count == archive.styles.count else {
                throw ExportError.message("The favorite archive has an invalid styles collection. No exports were written.")
            }
            for (index, style) in archive.styles.enumerated() {
                let encoded = try JSONEncoder().encode(style)
                guard let normalized = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
                      NSDictionary(dictionary: sourceStyles[index]).isEqual(NSDictionary(dictionary: normalized)) else {
                    throw ExportError.message("Favorite \(index + 1) would require normalization or has unsupported fields. Refusing to change a saved preference; no exports were written.")
                }
            }

            let files = try SeaGlassStyleExporter.exportFiles(styles: archive.styles, directory: output)
            let provenance = Provenance(
                version: 1,
                sourceLabel: "Saved favorite archive supplied by caller",
                sourcePath: input.path,
                exportedAt: ISO8601DateFormatter().string(from: Date()),
                favoriteCount: archive.styles.count,
                favorites: archive.styles.map { Favorite(id: $0.id, name: $0.name) },
                outputs: [files.jsonURL.lastPathComponent, files.swiftURL.lastPathComponent],
                preservation: "Names, notes, IDs and every recipe field were verified unchanged before export."
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let provenanceURL = output.appendingPathComponent("PhoneStyleProvenance.json")
            try encoder.encode(provenance).write(to: provenanceURL, options: .atomic)
            print("Exported \(archive.styles.count) saved favorite\(archive.styles.count == 1 ? "" : "s") without changing their recipes.")
            print(files.jsonURL.path)
            print(files.swiftURL.path)
            print(provenanceURL.path)
        } catch {
            FileHandle.standardError.write(Data("Sea Glass favorite export: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private struct Archive: Decodable { let version: Int; let styles: [SeaGlassStyle] }
    private struct Favorite: Encodable { let id: UUID; let name: String }
    private struct Provenance: Encodable {
        let version: Int
        let sourceLabel: String
        let sourcePath: String
        let exportedAt: String
        let favoriteCount: Int
        let favorites: [Favorite]
        let outputs: [String]
        let preservation: String
    }
    private enum ExportError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self { case .message(let message): message }
        }
    }
}
