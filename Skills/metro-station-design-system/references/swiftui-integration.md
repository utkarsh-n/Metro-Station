# SwiftUI integration

Use [the full specification](design-system-spec.md) for exact recipes, optical math and domain adaptations. The [editable visual atlas](../assets/visual-reference.svg) and [PNG preview](../assets/visual-reference.png) are schematic references; their glass drawings are not native material screenshots.

## App-target installation

Use an iPhone SwiftUI app target with iOS 26 or later and Swift 6. The original Metro Station app targets iOS 27. Add these four files to the same app target:

- [InstrumentDesignSystem.swift](../assets/swiftui-starter/InstrumentDesignSystem.swift)
- [InstrumentControlTouchBoundary.swift](../assets/swiftui-starter/InstrumentControlTouchBoundary.swift)
- [LensRefraction.swift](../assets/swiftui-starter/LensRefraction.swift)
- [UsageExample.swift](../assets/swiftui-starter/UsageExample.swift)

Also add [InstrumentLensOptics.metal](../assets/swiftui-starter/InstrumentLensOptics.metal) to that target so Xcode compiles `instrumentLensOptics` into the app's default shader library. The starter calls `ShaderLibrary.instrumentLensOptics`; adding Metal as an uncompiled copy-only resource does not satisfy this lookup.

Moving these components into a Swift package or framework requires an explicit compiled-shader resource/library strategy and a lookup that resolves that bundle. The supplied app-target lookup is not a drop-in package configuration, and this skill supplies no `Package.swift`. Check shader resolution in the destination app, including Release builds.

The [token JSON](../assets/design-tokens.json) is a reference manifest. The Swift components use typed values and do not load it at runtime. No MetronomeCore module or third-party runtime dependency is required.

For selective adoption, extract the needed foundation types into the host's existing design namespace, or include their source dependencies. The complete InstrumentDesignSystem.swift declares types that reference both the touch bridge and LensRefraction, even when a particular screen does not instantiate the lens. The all-four-file instructions above describe the complete demonstration, not a requirement to copy the example screen into every app.

The supplied integer Stepper formats its stored integer directly. Quantities stored as tenths or as a preset index need a domain-formatted native Stepper or an adapted label; display the actual voltage or resistor value rather than the encoded count/index.

To inspect composition in an existing app:

~~~swift
WindowGroup {
    InstrumentDesignUsageExample()
}
~~~

The example is an angle explorer with degrees, radians, a calibrated pointer, native glass controls and an integer Stepper. Replace it with the destination app's meaningful quantity and vocabulary. It supplies no audio engine, haptic engine or motion manager.

## State and accepted-change ownership

`InstrumentParameterStepper` writes its Binding before calling `onAcceptedChange`. That callback is a post-write notification for feedback or dependent work. If the Binding setter already sends a domain command, do not send the same command again from the notification. Unchanged clamped values create no accepted-change callback.

Keep persistent controls outside high-frequency drawing timelines. Draw from prepared, acknowledged domain state where output fidelity matters, and identify requested values separately when relevant. The host owns the authoritative clock, sound/haptics, formatting, units, limits and valid initial state.

Compose `InstrumentLensSurface` with a decorative SwiftUI face and a separate foreground readout. Prefer Canvas or Shapes for filtered content; UIKit-backed views cannot be assumed to participate in `layerEffect`. Readouts and controls stay outside optical sampling. Pass a bounded radius scale from the host's clock rather than introducing a competing presentation timer.

## Motion, lifecycle and touch

Supply a filtered tilt vector mapped to the current screen coordinate system. The host owns CoreMotion availability, permission/usage description, orientation mapping, sensor start/stop and scene lifecycle. The starter gates custom optical rendering for inactive scenes, Reduce Motion and Reduce Transparency; it does not stop a host sensor service or timeline. Stop or pause those explicitly when appropriate, and return decorative motion to a useful resting presentation.

Apply `instrumentControlOwnsTouches` to the actual framed control bounds, including native button edges. It protects the nearest containing UIScrollView pan during touches beginning in that marker. Higher nested scroll views and presentation-dismissal gestures need separate checks. Touches beginning elsewhere should retain ordinary page scrolling.

## Accessibility and validation scope

Provide meaningful spoken quantities, units, state and adjustable actions. Keep accepted changes useful to VoiceOver without announcing every drawing frame. Validate large Dynamic Type, longer localized values, Reduce Motion, Reduce Transparency, Increased Contrast and full control-edge access in the destination screen.

The large readout preserves proportional instrument geometry. Where large text is essential, supply a scalable adjacent value or alternative composition. The starter's scalable Stepper labels/value, accessibility-size stacking, opaque panels under Reduce Transparency and strengthened panel borders are adoption aids, not accessibility certification. Color tokens and nominal opacity do not establish composited contrast.

The original edition recorded Swift 6 type-checking for arm64 iOS 26 with the iOS 27 SDK, Metal compile/link checks, token checks and atlas inspection. These are historical source-edition checks. The example did not receive a separate installed-app runtime or hardware test, and copied assets do not validate a new app.

Check the actual destination app/device: native glass and shader rendering; held repeats and direction changes while drawing; complete control-edge touch ownership; unchanged foreground/control geometry under tilt; idle/inactive lifecycle; accessible and localized layouts; and relevant output interruptions. Distinguish compile checks, sampled native images/contact traces, continuous frame pacing, engine PCM, acoustic listening and perceived haptics. Section 20 of [the specification](design-system-spec.md) preserves the original app's partial QA results and limits; no baseline QA receipt is bundled as adopting-app proof.
