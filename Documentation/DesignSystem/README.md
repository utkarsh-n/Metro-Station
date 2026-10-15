# Metro Station Design System Starter

Edition 1.0 · Extracted from Metro Station build 14 · October 12, 2026

Start with [the full design specification](MetroStationDesignSystem.md). It documents exact current tuning, recommended adoption rules, material hierarchy, component anatomy, touch ownership, typography, optical math and domain adaptations. [The visual atlas](VisualReference.svg) is editable; the PNG is its rendered preview. Glass in the atlas is schematic.

## Add the starter to a SwiftUI app

1. Use an iPhone SwiftUI target with an iOS 26 or later deployment target and Swift 6. Metro Station itself targets iOS 27.
2. Add `InstrumentDesignSystem.swift`, `InstrumentControlTouchBoundary.swift`, `LensRefraction.swift` and `UsageExample.swift` to the app target.
3. Add `InstrumentLensOptics.metal` to that same target so Xcode includes `instrumentLensOptics` in the default shader library.
4. Present the example as the root of an existing app to inspect composition:

~~~swift
WindowGroup {
    InstrumentDesignUsageExample()
}
~~~

The example is an angle explorer. It uses legitimate degrees and radians, a calibrated pointer, native glass controls and a protected native Stepper. It supplies no motion manager, audio engine or haptic engine.

The JSON is a reference manifest. These Swift components use typed values and do not load it at runtime. No MetronomeCore module or other third-party runtime dependency is needed.

## Adapt to another domain

Use `InstrumentPalette` for semantic color and `InstrumentContentPanel` for quiet supporting information. Build one meaningful primary object, then compose `InstrumentLensSurface` with a decorative SwiftUI face and a separate `InstrumentLargeReadout`.

The lens accepts a filtered screen-space tilt vector and a bounded radius scale. The host owns sensor lifecycle, orientation mapping and domain timing. Pass valid acknowledged phase or event state to animated drawing. Decide explicitly which readouts reflect requested values and which depict output that actually occurred.

Keep controls outside high-frequency drawing timelines. `InstrumentParameterStepper` writes its Binding before calling `onAcceptedChange`. Use that notification for feedback or dependent work; do not publish the same domain change twice.

`instrumentControlOwnsTouches` protects the nearest containing UIScrollView pan for touches beginning inside the marked control. Nested scrolling and presentation gestures need their own checks. Apply it to the actual control bounds.

## Responsibilities retained by the host

- Domain model, valid initial state, formatting, units and limits.
- Sound, haptics, authoritative clocks and output acknowledgement.
- Screen-coordinate motion mapping and sensor lifecycle.
- Accessibility navigation, meaningful adjustable actions and larger-text composition.
- Native material rendering, gesture behavior and performance validation on the destination device.

The large dial readout reproduces the source's proportional geometry. If your screen needs larger accessibility text, provide the alternative layout described in the spec. The Stepper and panels include small adoption improvements; they are identified separately from source behavior.

## Validation included with this edition

The four Swift files type-check together in Swift 6 for an arm64 iOS 26 deployment target using the iOS 27 SDK. The Metal shader compiles using the installed Apple Metal toolchain. The atlas is rendered and visually inspected. `validation.json` records the scope, content hashes and source-baseline parity.

This is a compile-checked visual starter. The example has not undergone a separate installed-app runtime or hardware test. Metro Station's own historical and final-build evidence is documented with its limits in section 20 of the spec.

The portable files are intentionally separate from Metro Station's app sources. Copy this folder into another project, replace the angle example with that app's domain screen, then validate its complete interaction and accessibility behavior.

