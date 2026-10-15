# Metro Sea Glass · experimental extension 0.1

Use for a requested satin, weathered, colored translucent material. The core Metro Station hierarchy and source build 14 remain the baseline; this extension adds a selective tactile surface. Keep opaque instrument metal, calm content panels and the existing native clear lens in their established roles.

The supplied concept references motivate rounded worn shoulders, diffuse backdrop color and tinted depth. Primary microscopy of beach glass documents mechanical grooves together with chemical pits and cracks ([Corcoran et al., 2010](https://doi.org/10.2110/jsr.2010.077)). This kit illustrates those qualities with platform material and decorative layers. It does not model a calibrated glass BSDF, measured thickness, refraction or ray tracing. The supplied artwork's Google/Material 4 labels are unverified concept provenance; the kit is independently named Metro Sea Glass.

## Portable package

Add [../assets/sea-glass](../assets/sea-glass/Package.swift) as a local Swift Package and link its `MetroSeaGlass` product. Requires iOS 26+ and Swift 6, with no third-party dependency or Metal resource. Source files and [tokens](../assets/sea-glass/tokens.json) travel with the skill.

```swift
import MetroSeaGlass

let surface = SeaGlassConfiguration(
    frost: 0.64, depth: 0.55,
    lightDirection: .upperLeading, grain: 0.45
)

SeaGlassSurface(tint: .tide, configuration: surface, cornerRadius: 28) {
    VStack(alignment: .leading, spacing: 8) {
        Text("Output").font(.caption)
        Text("2.50 V").font(.title.monospacedDigit())
    }
    .padding(24)
}

Button("Apply") { /* host's accepted domain change */ }
    .buttonStyle(SeaGlassButtonStyle(tint: .tide, configuration: surface))
```

`SeaGlassSurface` supplies background only; its content owns dimensions, padding, foreground styles, units, valid precision and accessibility. `SeaGlassButtonStyle` sizes the native label to a minimum 44 × 44 points before decoration. Its shallow press response changes illustrated depth without shifting or scaling the foreground. It does not protect every ancestor scroll gesture automatically.

## Material rules

- Presets: `.tide`, `.kelp`, `.amber`, `.violet`, `.frost`. Material pigment does not establish domain status; preserve cyan/amber/violet meanings and pair status with text or symbols.
- `frost`, `depth` and `grain` are dimensionless artistic controls, clamped to 0...1. Frost adds a milky veil; SwiftUI controls the native `.ultraThinMaterial` blur. Depth illustrates bevel and contact shadow.
- Fine grain has a fixed seed and no clock. Keep it stationary and restrained.
- `SeaGlassLightDirection(x:y:)` uses screen coordinates (+x right, +y down), with length bounded to one. The host owns any filtered motion source and lifecycle. Only a thin rim arc follows light; foreground and broad face stay fixed. The package performs no angle interpolation, avoiding wrap spins.
- Use glass for a few touch surfaces, capsules or small windows. Keep charts and long explanations on quiet panels. Avoid large jelly-like squash, rainbow fringe or broad moving face glints.
- Reduce Transparency gives an opaque tint-specific fill and removes grain/reflection. Reduce Motion fixes upper-leading light. Increased Contrast strengthens the edge. The optional `forceOpaque` and `staticLight` preview flags OR with system preferences; they cannot disable system accommodations.

## Validation scope

The source module typechecks for arm64 iOS 26 Simulator with the Xcode 27 SDK. A separate iPhone lab built and ran on an iOS 27 Simulator, with native dark/light rendering, opaque/static comparisons, pin/reset actions and an accessibility-size layout inspected. Browser workbench tests independently exercise the artistic recipe; browser and SwiftUI compositing are not pixel-identical.

Compile and inspect every adopting app independently. Check composited contrast, actual native hit edges, held/repeat gestures, long labels and large Dynamic Type. Host-owned sensors, audio and haptics require their own hardware checks. The material study includes no physical-phone validation or continuous frame-pacing measurement.
