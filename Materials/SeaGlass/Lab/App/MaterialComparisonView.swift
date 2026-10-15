import SwiftUI
import MetroSeaGlass

/// A recipe snapshot and the live recipe share geometry, decorative ink, and sampling content.
/// The host owns both values; pinning never edits the user's saved style library.
struct MaterialComparisonView: View {
    let style: SeaGlassStyle
    @Binding var referenceStyle: SeaGlassStyle
    let backdrop: LabBackdrop

    init(style: SeaGlassStyle, referenceStyle: Binding<SeaGlassStyle>, backdrop: LabBackdrop = .signal) {
        self.style = style
        _referenceStyle = referenceStyle
        self.backdrop = backdrop
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var specimenHeight: CGFloat = 190
    @State private var pinStatus: String?

    private var mineral: Bool { style.appearance == .mineral }
    private var ink: Color { comparisonInk(style) }
    private var secondaryInk: Color {
        mineral ? Color(red: 0.28, green: 0.39, blue: 0.40) : Color(red: 0.61, green: 0.73, blue: 0.76)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Text("03 / MATERIAL COMPARISON")
                    .font(.caption2.monospaced())
                    .tracking(1.7)
                    .foregroundStyle(secondaryInk)
                Text("See what changed.")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("Both surfaces share the same backdrop, light and comparison settings. Sharp ink stays above the material.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 18) { comparisonCells }
            } else {
                HStack(alignment: .top, spacing: 12) { comparisonCells }
            }

            parameterComparison

            Button {
                referenceStyle = style
                pinStatus = "Reference updated to \(style.name)."
            } label: {
                Label("Use current as reference", systemImage: "pin")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                    .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(ink.opacity(0.16)) }
                    .contentShape(RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Copies the current recipe into the reference. Saved styles are unchanged.")
            .accessibilityIdentifier("comparison.use-current-as-reference")

            VStack(alignment: .leading, spacing: 6) {
                Text("Reference tint, frost, depth, grain and roundness stay fixed. Current light and opacity settings apply to both. Frost, depth and grain are artistic indices from 0 to 100.")
                if let pinStatus {
                    Text(pinStatus).accessibilityIdentifier("comparison.status")
                }
            }
            .font(.caption)
            .foregroundStyle(secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(ink)
    }

    @ViewBuilder private var comparisonCells: some View {
        comparisonCell(referenceStyle, title: "Reference", identifier: "reference")
        comparisonCell(style, title: "Current", identifier: "current")
    }

    private func comparisonCell(_ recipe: SeaGlassStyle, title: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.caption2.monospaced().weight(.medium))
                    .tracking(1.2)
                    .foregroundStyle(secondaryInk)
                Text(recipe.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(2, reservesSpace: true)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(recipe.appearance == .mineral
                          ? Color(red: 0.88, green: 0.93, blue: 0.91)
                          : Color(red: 0.025, green: 0.042, blue: 0.058))
                LabBackdropView(backdrop: backdrop, isMineral: recipe.appearance == .mineral)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                SeaGlassSurface(
                    tint: SeaGlassTint(rawValue: recipe.tint.rawValue) ?? .tide,
                    configuration: comparisonConfiguration(recipe, settings: style),
                    cornerRadius: CGFloat(recipe.cornerRadius)
                ) {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(14)

                // Foreground text is a sibling of the surface, never a sampled material layer.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aa")
                        .font(.system(.largeTitle, design: .serif, weight: .regular))
                    Text("SHARP INK")
                        .font(.caption2.monospaced())
                        .tracking(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(comparisonInk(recipe))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(30)
                .allowsHitTesting(false)
            }
            .frame(height: specimenHeight)
            .environment(\.colorScheme, recipe.appearance == .mineral ? .light : .dark)
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(ink.opacity(0.10)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) material specimen, \(recipe.name)")
            .accessibilityValue(accessibilityRecipe(recipe))
            .accessibilityIdentifier("comparison.specimen.\(identifier)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var parameterComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(row.title).font(.subheadline.weight(.semibold))
                        LabeledContent("Reference", value: row.reference)
                        LabeledContent("Current", value: row.current)
                    }
                    .font(.caption)
                    .padding(.vertical, 5)
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 11) {
                    GridRow {
                        Text("RECIPE")
                        Text("REFERENCE")
                        Text("CURRENT")
                    }
                    .font(.caption2.monospaced())
                    .foregroundStyle(secondaryInk)
                    ForEach(rows) { row in
                        GridRow {
                            Text(row.title)
                                .foregroundStyle(secondaryInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.reference)
                            Text(row.current)
                        }
                        .font(.caption)
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(row.title), reference \(row.reference), current \(row.current)")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ink.opacity(0.025), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(ink.opacity(0.08)) }
    }

    private var rows: [ComparisonRecipeRow] {
        [
            .init(title: "Tint", reference: referenceStyle.tint.displayName, current: style.tint.displayName),
            .init(title: "Frost", reference: index(referenceStyle.frost), current: index(style.frost)),
            .init(title: "Depth", reference: index(referenceStyle.depth), current: index(style.depth)),
            .init(title: "Grain", reference: index(referenceStyle.grain), current: index(style.grain)),
            .init(title: "Roundness", reference: "\(Int(referenceStyle.cornerRadius.rounded())) pt", current: "\(Int(style.cornerRadius.rounded())) pt"),
            .init(title: "Environment", reference: referenceStyle.appearance.displayName, current: style.appearance.displayName),
            .init(title: "Surface", reference: surfaceDescription(referenceStyle), current: surfaceDescription(style)),
            .init(title: "Rim light", reference: lightDescription(referenceStyle), current: lightDescription(style))
        ]
    }

    private func index(_ value: Double) -> String { "\(Int((value * 100).rounded()))" }

    private func surfaceDescription(_ recipe: SeaGlassStyle) -> String {
        style.forceOpaque || reduceTransparency ? "Opaque" : "Translucent"
    }

    private func lightDescription(_ recipe: SeaGlassStyle) -> String {
        if style.forceOpaque || reduceTransparency { return "Hidden" }
        if style.staticLight || reduceMotion { return "Fixed" }
        return "\(Int(style.lightAngleDegrees.rounded()))°"
    }

    private func accessibilityRecipe(_ recipe: SeaGlassStyle) -> String {
        let rim: String
        if style.forceOpaque || reduceTransparency {
            rim = "Rim light hidden by the opaque surface. Stored frost and grain are inactive."
        } else if style.staticLight || reduceMotion {
            rim = "Rim light fixed at upper left."
        } else {
            rim = "Shared rim light \(Int(style.lightAngleDegrees.rounded())) degrees clockwise from right."
        }
        return "\(recipe.tint.displayName) tint, \(recipe.appearance.displayName) environment. Frost \(index(recipe.frost)) of 100, depth \(index(recipe.depth)) of 100, grain \(index(recipe.grain)) of 100. Roundness \(Int(recipe.cornerRadius.rounded())) points. Stored light angle \(Int(recipe.lightAngleDegrees.rounded())) degrees clockwise from right. Stored opaque override \(recipe.forceOpaque ? "on" : "off"), stored static light override \(recipe.staticLight ? "on" : "off"). This comparison uses the current recipe’s opaque override \(style.forceOpaque ? "on" : "off") and static light override \(style.staticLight ? "on" : "off") for both specimens. System Reduce Transparency \(reduceTransparency ? "on" : "off"), Reduce Motion \(reduceMotion ? "on" : "off"). \(surfaceDescription(recipe)) surface. \(rim) Foreground letters Aa remain sharp. The \(backdrop.rawValue) decorative backdrop and effective light settings are shared by both specimens."
    }
}

private struct ComparisonRecipeRow: Identifiable {
    let title: String
    let reference: String
    let current: String
    var id: String { title }
}

private func comparisonInk(_ recipe: SeaGlassStyle) -> Color {
    recipe.appearance == .mineral
        ? Color(red: 0.07, green: 0.17, blue: 0.18)
        : Color(red: 0.91, green: 0.95, blue: 0.97)
}

private func comparisonConfiguration(_ recipe: SeaGlassStyle, settings: SeaGlassStyle) -> SeaGlassConfiguration {
    let radians = settings.lightAngleDegrees * .pi / 180
    return SeaGlassConfiguration(
        frost: recipe.frost, depth: recipe.depth,
        lightDirection: SeaGlassLightDirection(x: cos(radians), y: sin(radians)),
        grain: recipe.grain, forceOpaque: settings.forceOpaque, staticLight: settings.staticLight
    )
}
