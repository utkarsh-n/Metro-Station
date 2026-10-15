# Metro Sea Glass · native experiment

An optional satin translucent material for Metro Station, supporting iOS 26+ with Swift 6. Add this folder as a local Swift Package and link the `MetroSeaGlass` product. It has no third-party dependencies, Metal resources, sensor service, or presentation clock.

The recipe combines native `.ultraThinMaterial`, a muted pigment wash, milky scattering overlays, deterministic fine grain, a soft inward shoulder and a restrained perimeter reflection. It is a custom SwiftUI surface, not Apple's Liquid Glass, measured sea-glass optics, refraction or ray tracing. `frost` controls the custom overlay; native blur remains system-controlled.

Recipe revision 2 replaces the former narrow colored outline with two softly blurred pigment bands and a static matte bevel. Their falloff rolls inward from the edge while leaving the face clear. The shoulder is capped at 18% of the shortest surface dimension, so small native buttons keep a usable center. Stronger muted pigment and a lighter neutral ink bed give the dark appearance more color and less gray. The small light arc is softer and remains confined to the perimeter; there is no moving face highlight or rainbow separation.

The native backdrop is an ungrouped sibling of the decorative drawing. Blur applies only to the shoulder shapes and a faint rim reflection, clipped inside the surface. Contact shadows come from an independent shadow-only Canvas with its interior erased, preventing an opaque silhouette from entering the backdrop. Foreground content sits outside all these drawing layers. Public APIs, tint values and stored recipe parameters are unchanged, so saved styles and generated source remain compatible.

```swift
import MetroSeaGlass

let material = SeaGlassConfiguration(
    frost: 0.64,
    depth: 0.55,
    lightDirection: .upperLeading,
    grain: 0.45
)

SeaGlassSurface(tint: .tide, configuration: material, cornerRadius: 28) {
    VStack(alignment: .leading, spacing: 8) {
        Text("Continuous signal").font(.caption)
        Text("440 Hz").font(.system(.largeTitle, design: .rounded)).monospacedDigit()
    }
    .padding(24)
}

Button("Apply") { /* accepted domain change */ }
    .buttonStyle(SeaGlassButtonStyle(tint: .tide, configuration: material))
```

`SeaGlassSurface` adds a background only. Its content owns layout, padding, semantic foreground styles, accessibility labels, units and valid precision. Use the existing Metro dark canvas and opaque instrument housing; introduce Sea Glass selectively for a control shelf, a mode selector or a single focused object. Keep plots and long explanations on quiet supporting panels.

The five pigment presets are `.tide`, `.kelp`, `.amber`, `.violet` and `.frost`. Their pigment `Color` and human-readable `name` are public. The tint alone must not communicate status; pair it with text, position or a symbol. Existing Metro color meanings still apply.

`frost`, `depth` and `grain` are dimensionless values clamped to 0...1, including subsequent mutation. Nonfinite values become zero. `SeaGlassLightDirection(x:y:)` uses screen coordinates (+x right, +y down) and clamps vector length to one. A filtered host motion source can supply it; this package starts no sensor. Light changes affect the perimeter arc only. The package applies no rim interpolation, avoiding angle-wrap rotations when the direction crosses ±180°. Foreground content and the broad face remain fixed.

`SeaGlassButtonStyle` supplies horizontal/vertical padding and a minimum 44 × 44 pt native label/hit surface. Pressing reduces the illustrated depth without scaling or shifting the label. The host owns accepted-change feedback and repeat behavior. Check edge touches inside the destination scroll view; a custom ButtonStyle does not automatically protect every ancestor scroll or sheet gesture.

Reduce Transparency uses a fully opaque tint-specific fill and disables the blurred shoulder, grain and moving reflection. Reduce Motion fixes the reflection to upper-leading light. `SeaGlassConfiguration(forceOpaque: true)` and `SeaGlassConfiguration(staticLight: true)` let a material lab preview those treatments. These flags are additive: the effective value is the system preference OR the preview flag, so a lab cannot disable an enabled system accommodation. Both default to `false`. Increased Contrast strengthens the perimeter. Foreground labels inherit native semantic colors. These accommodations do not certify contrast over every background or at every type size.

`tokens.json` records the recipe; the Swift module uses typed constants and does not load JSON at runtime.

Validation on October 13, 2026: Swift 6 typecheck for arm64 iOS 26 Simulator against the Xcode 27 SDK passed. Swift Package manifest validation passed after directing compiler caches into `/tmp`. No installed-device rendering, continuous frame pacing, composited contrast, VoiceOver or full control-edge gesture assessment is implied by compilation.
