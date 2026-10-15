import SwiftUI
import UIKit
import MetroSeaGlass

/// The lab owns the current recipe. This view owns only its local variations and presentations.
struct StyleWorkbenchView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var style: SeaGlassStyle
    let library: SeaGlassStyleLibrary

    @State private var variants: [SeaGlassStyle] = []
    @State private var variationSeed: UInt64 = 0x534541
    @State private var presentedSheet: StyleWorkbenchSheet?
    @State private var status: String?

    private var mineral: Bool { style.appearance == .mineral }
    private var ink: Color { mineral ? Color(red: 0.07, green: 0.17, blue: 0.18) : Color(red: 0.91, green: 0.95, blue: 0.97) }
    private var secondaryInk: Color { mineral ? Color(red: 0.28, green: 0.39, blue: 0.40) : Color(red: 0.61, green: 0.73, blue: 0.76) }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading
            generateButton
            Button {
                presentedSheet = .save(style)
            } label: {
                Label("Save current style", systemImage: "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SeaGlassButtonStyle(tint: materialTint(style), configuration: materialConfiguration(style)))
            .accessibilityIdentifier("style.save-current")

            if !variants.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(variants) { variant in
                        StyleVariantCard(style: variant, selected: sameRecipe(style, variant), outerInk: ink) {
                            style = variant
                            status = "Applied \(variant.name)."
                        }
                    }
                }
            }

            favorites
            exportActions
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
                    .accessibilityIdentifier("style.status")
            }
            if let error = library.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
            }
        }
        .foregroundStyle(ink)
        .onAppear {
            if variants.isEmpty {
                variants = SeaGlassVariantGenerator.generate(from: style, seed: variationSeed)
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .save(let snapshot):
                SaveSeaGlassStyleSheet(snapshot: snapshot, library: library)
            case .share(let files):
                SeaGlassStyleShareSheet(urls: files.urls)
            case .code(let code):
                SeaGlassStyleCodeSheet(source: code.source, mineral: mineral)
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MATERIAL COLLECTION")
                .font(.caption2.monospaced())
                .tracking(1.7)
                .foregroundStyle(secondaryInk)
            Text("Keep the good ones.")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Save what you like, then export the styles to share them here.")
                .font(.subheadline)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var generateButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                variationSeed &+= 1
                variants = SeaGlassVariantGenerator.generate(from: style, seed: variationSeed)
                status = "Four local variations generated. Tap one to apply it."
            } label: {
                Label("Generate variants", systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SeaGlassButtonStyle(tint: .frost, configuration: materialConfiguration(style)))
            .accessibilityIdentifier("style.generate")
            Text("Four reproducible variations of your current recipe, generated on this iPhone.")
                .font(.caption)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Saved styles").font(.headline)
                Spacer()
                Text("\(library.styles.count)")
                    .font(.caption.monospaced())
                    .monospacedDigit()
                    .foregroundStyle(secondaryInk)
            }
            if library.styles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Your collection starts here", systemImage: "bookmark")
                        .font(.subheadline.weight(.medium))
                    Text("Apply a variant or adjust the recipe, then give it a name and save it.")
                        .font(.caption)
                        .foregroundStyle(secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(library.styles) { saved in
                    savedRow(saved)
                }
            }
        }
        .padding(.top, 6)
    }

    private func savedRow(_ saved: SeaGlassStyle) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                style = saved
                status = "Applied \(saved.name)."
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    SeaGlassSurface(tint: materialTint(saved), configuration: materialConfiguration(saved), cornerRadius: 14) {
                        Image(systemName: "water.waves")
                            .font(.title3)
                            .foregroundStyle(previewInk(saved))
                            .frame(width: 54, height: 54)
                    }
                    .environment(\.colorScheme, saved.appearance == .mineral ? .light : .dark)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(saved.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ink)
                        Text("\(saved.tint.displayName) · \(saved.appearance.displayName)")
                            .font(.caption)
                            .foregroundStyle(secondaryInk)
                        if !saved.notes.isEmpty {
                            Text(saved.notes)
                                .font(.caption)
                                .foregroundStyle(secondaryInk)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: sameRecipe(style, saved) ? "checkmark.circle.fill" : "arrow.up.left")
                        .font(.caption)
                        .foregroundStyle(secondaryInk)
                }
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apply \(saved.name), \(saved.tint.displayName), \(saved.appearance.displayName)")
            .accessibilityHint(saved.notes.isEmpty ? "Loads this saved recipe into the specimen." : saved.notes)
            .accessibilityIdentifier("style.apply-saved.\(saved.id.uuidString)")

            Button(role: .destructive) {
                if library.delete(id: saved.id) {
                    status = "Removed \(saved.name) from saved styles."
                }
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(saved.name)")
            .accessibilityIdentifier("style.remove-saved.\(saved.id.uuidString)")
        }
        .padding(12)
        .background(ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(ink.opacity(0.08)) }
    }

    private var exportActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                do {
                    let files = try SeaGlassStyleExporter.exportFiles(styles: library.styles)
                    presentedSheet = .share(StyleShareFiles(urls: [files.jsonURL, files.swiftURL]))
                    status = "Choose Files or another destination in the share sheet."
                } catch {
                    status = "Could not prepare the export: \(error.localizedDescription)"
                }
            } label: {
                Label("Export saved styles", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SeaGlassButtonStyle(tint: .frost, configuration: materialConfiguration(style)))
            .disabled(library.styles.isEmpty)
            .accessibilityIdentifier("style.export")
            Text("Includes the named recipes and notes, plus reusable Swift styles. Saved styles stay on this iPhone between launches.")
                .font(.caption)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                presentedSheet = .code(StyleCodePreview(source: SeaGlassStyleExporter.swiftSource(styles: library.styles)))
            } label: {
                Label("Preview Swift export", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption.weight(.medium))
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(library.styles.isEmpty)
            .accessibilityIdentifier("style.preview-code")
        }
    }
}

private struct StyleVariantCard: View {
    let style: SeaGlassStyle
    let selected: Bool
    let outerInk: Color
    let apply: () -> Void

    private var mineral: Bool { style.appearance == .mineral }

    var body: some View {
        Button(action: apply) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(mineral ? Color(red: 0.86, green: 0.92, blue: 0.89) : Color(red: 0.025, green: 0.042, blue: 0.058))
                    StylePreviewSignal(mineral: mineral)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    SeaGlassSurface(tint: materialTint(style), configuration: materialConfiguration(style), cornerRadius: CGFloat(style.cornerRadius * 0.5)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(style.tint.displayName.uppercased())
                                    .font(.caption2.monospaced())
                                    .tracking(0.7)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "checkmark.circle.fill")
                                    .opacity(selected ? 1 : 0)
                                    .font(.caption)
                            }
                            Text("Aa")
                                .font(.system(.largeTitle, design: .serif, weight: .regular))
                        }
                        .foregroundStyle(previewInk(style))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .environment(\.colorScheme, mineral ? .light : .dark)
                }
                .frame(minHeight: 118)
                Text(style.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(outerInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Frost \(percent(style.frost)) · Depth \(percent(style.depth))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(outerInk.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(outerInk.opacity(0.025), in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(outerInk.opacity(selected ? 0.4 : 0.08), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.name), \(style.tint.displayName), \(style.appearance.displayName), frost \(percent(style.frost)), depth \(percent(style.depth))")
        .accessibilityHint("Applies this local variation to the specimen.")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("style.variant.\(style.id.uuidString)")
    }
}

private struct SaveSeaGlassStyleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: SeaGlassStyle
    let library: SeaGlassStyleLibrary
    @State private var name: String
    @State private var notes: String
    @State private var saveError: String?

    init(snapshot: SeaGlassStyle, library: SeaGlassStyleLibrary) {
        self.snapshot = snapshot
        self.library = library
        _name = State(initialValue: snapshot.name)
        _notes = State(initialValue: snapshot.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Style name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("style.save-name")
                    TextField("Notes, optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("style.save-notes")
                } header: {
                    Text("Make it yours")
                } footer: {
                    Text("The current recipe is saved as a new named style on this iPhone.")
                }
                Section("Recipe") {
                    LabeledContent("Tint", value: snapshot.tint.displayName)
                    LabeledContent("Environment", value: snapshot.appearance.displayName)
                    LabeledContent("Frost", value: percent(snapshot.frost))
                    LabeledContent("Depth", value: percent(snapshot.depth))
                }
                if let saveError {
                    Section { Label(saveError, systemImage: "exclamationmark.circle") }
                }
            }
            .navigationTitle("Save style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if library.saveSnapshot(of: snapshot, name: name, notes: notes) != nil {
                            dismiss()
                        } else {
                            saveError = library.error ?? "The style could not be saved."
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("style.confirm-save")
                }
            }
        }
        .preferredColorScheme(snapshot.appearance == .mineral ? .light : .dark)
    }
}

private struct SeaGlassStyleCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: String
    let mineral: Bool
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(copied ? "Swift styles copied." : "Reusable Swift styles for your saved collection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                ScrollView([.horizontal, .vertical]) {
                    Text(source)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(20)
                }
            }
            .padding(.top, 12)
            .navigationTitle("Swift export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") {
                        UIPasteboard.general.string = source
                        copied = true
                    }
                    .accessibilityIdentifier("style.copy-code")
                }
            }
        }
        .preferredColorScheme(mineral ? .light : .dark)
    }
}

private struct SeaGlassStyleShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct StylePreviewSignal: View {
    let mineral: Bool

    var body: some View {
        Canvas { context, size in
            for (index, color) in [Color.cyan, .orange, .purple].enumerated() {
                var path = Path()
                path.move(to: CGPoint(x: -10, y: size.height * 0.8 + Double(index) * 15))
                path.addCurve(to: CGPoint(x: size.width + 10, y: 12 + Double(index) * 15),
                              control1: CGPoint(x: size.width * 0.25, y: size.height),
                              control2: CGPoint(x: size.width * 0.7, y: 0))
                context.stroke(path, with: .color(color.opacity(mineral ? 0.55 : 0.45)), lineWidth: 8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum StyleWorkbenchSheet: Identifiable {
    case save(SeaGlassStyle)
    case share(StyleShareFiles)
    case code(StyleCodePreview)

    var id: String {
        switch self {
        case .save: "save"
        case .share(let files): files.id.uuidString
        case .code(let code): code.id.uuidString
        }
    }
}

private struct StyleShareFiles { let id = UUID(); let urls: [URL] }
private struct StyleCodePreview { let id = UUID(); let source: String }

private func materialTint(_ style: SeaGlassStyle) -> SeaGlassTint {
    SeaGlassTint(rawValue: style.tint.rawValue) ?? .tide
}

private func materialConfiguration(_ style: SeaGlassStyle) -> SeaGlassConfiguration {
    let radians = style.lightAngleDegrees * .pi / 180
    return SeaGlassConfiguration(frost: style.frost, depth: style.depth,
                                 lightDirection: SeaGlassLightDirection(x: cos(radians), y: sin(radians)),
                                 grain: style.grain, forceOpaque: style.forceOpaque, staticLight: style.staticLight)
}

private func previewInk(_ style: SeaGlassStyle) -> Color {
    style.appearance == .mineral ? Color(red: 0.07, green: 0.17, blue: 0.18) : Color(red: 0.91, green: 0.95, blue: 0.97)
}

private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

private func sameRecipe(_ lhs: SeaGlassStyle, _ rhs: SeaGlassStyle) -> Bool {
    lhs.tint == rhs.tint && lhs.appearance == rhs.appearance && lhs.frost == rhs.frost
        && lhs.depth == rhs.depth && lhs.grain == rhs.grain && lhs.lightAngleDegrees == rhs.lightAngleDegrees
        && lhs.cornerRadius == rhs.cornerRadius && lhs.forceOpaque == rhs.forceOpaque && lhs.staticLight == rhs.staticLight
}
