---
name: metro-station-design-system
description: "Default design system for new native SwiftUI iPhone apps. Adapt Metro Station's Liquid Glass, metal, instruments, controls and visualizers to each app's domain. Continue in apps already using it; also use for requested adoption or restyling."
---

# Metro Station Design System

Metro Station is the user's default design system for future native SwiftUI iPhone apps. Apply this skill when starting a new app without requiring an explicit style request. An explicit alternative visual direction takes precedence. Continue the system in apps already using Metro Station. Other existing apps retain their established design unless the task adopts or requests a restyle to Metro Station.

Adapt the instruments, controls and visualizers to the app's purpose. Preserve its product, brand, domain model, units, valid precision and architecture. Choose a primary object that communicates its domain: a circuit, spatial model, timeline, progress surface, content view or gauge. Map controls to meaningful increments and named states; make visualizers depict the app's actual or clearly modeled signals. Adopt the smallest useful component set rather than requiring a dial, crowns or spectral pills on every screen.

The bundled edition 1.0 is extracted from Metro Station build 14. Its spec separates current tuning from recommended adoption improvements. Read the relevant sections rather than loading every reference for a narrow edit.

## Reference routing

| Work | Read |
| --- | --- |
| New app, screen already using Metro Station, or requested adoption/restyle | [Design spec](references/design-system-spec.md), sections 1–7 for foundations and layer/state ownership; section 19 for domain adaptation. |
| Gauge, Stepper, crowns, signal channels or transport | Spec sections 8–12 for the component being built. |
| Tilt, lens refraction, edge light or chromatic detail | Spec sections 13–14. |
| Adjustment detents, sound or synchronized events | Spec section 15; keep its hardware and clock limits explicit. |
| Accessibility or validation of a changed behavior | Spec sections 17 and 20. |
| Copying starter code into a target | [SwiftUI integration](references/swiftui-integration.md) and spec section 18. |
| Exact colors and dimensions | [Token manifest](assets/design-tokens.json); RGB doubles are canonical, hex is approximate. |
| Visual reference | Inspect [PNG atlas](assets/visual-reference.png). The [editable SVG](assets/visual-reference.svg) depicts glass schematically. |
| Building a metronome specifically | Spec section 21. Keep those BPM, rhythm and kernel rules in the domain adapter. |
| Sea Glass, satin frosting, worn colored glass or a requested material exploration | [Experimental Sea Glass extension](references/sea-glass.md). The reusable iOS 26+ package is in `assets/sea-glass/`. |

## Apply the system

Inspect the existing screen, state owners and deployment target before adapting it. Establish a semantic palette, quiet supporting panels, stable typography and one meaningful primary object. Add signal channels and tactile detail when they communicate independent information.

Retain these material and interaction decisions unless the user directs otherwise:

- Use near-black blue-green surroundings, quiet content panels, precise opaque metal and native Liquid Glass as distinct material roles. Keep native glass on controls and an isolated lens; supporting charts and explanations stay calm.
- Use cyan for continuous signal/control, amber for events/emphasis and violet/magenta for a distinct secondary channel. Pair color with position, text or shape.
- Keep values, units, meaning and actual control frames outside sensor transforms, optical filters and high-frequency drawing timelines. Stable identity allows native held repeat to continue.
- Separate requested values from acknowledged output. Give each displayed quantity an explicit owner. Preserve authoritative phase through rate changes; do not imply requested settings are already sounding.
- Keep the glass lens centered and its opacity constant. A domain-driven radius bounce is optional. Restrict moving light to a faint rim arc; keep the face clear and color separation subtle at diagonal edges.
- Keep signal-pill outlines and labels constant. Express events with meaningful interior attack/decay or geometry, rather than a blinking enclosure.
- Format integer quantities with whole digits. Preserve legitimate precision in other units and show those units.
- Make fine, semantic and directional adjustments distinct. Provide native controls and accessible actions alongside custom gestures. Emit feedback once per accepted change, with bounded event density.
- Size actual native labels/hit surfaces before glass styling. Preserve touches beginning on a control for the full contact sequence.

Apply the smallest useful set of [starter assets](assets/swiftui-starter/). Integrate them with the app's existing architecture. The supplied components target iOS 26+; the source app targets iOS 27. Use available native APIs and inspect current SDK/documentation when compatibility is uncertain. Provide a deliberate fallback if the product requires an older target.

## Implementation boundaries

Sea Glass is an optional experimental material, independent of the edition 1.0 native clear lens. Adopt it when the requested art direction calls for a frosted colored surface; keep supporting content quiet and retain the same anchored-readout and touch contracts. Its custom SwiftUI layers approximate scattering rather than physical refraction. Read the extension before copying it.

The starter supplies visual primitives, an integer Stepper, a touch bridge, bounded lens math, a Metal shader and an angle-explorer example. The host owns domain models, clocks, audio, haptics, motion lifecycle, orientation mapping and formatting.

The Stepper writes its Binding before `onAcceptedChange`. Treat the callback as a post-write notification; avoid publishing the same domain change twice.

The touch bridge protects the nearest containing UIScrollView pan. Higher nested scrolling and sheet dismissal gestures require their own host checks. A fixed outer frame alone does not prove the native button owns every edge touch.

Apply the optical shader only to decorative SwiftUI drawing. Keep native glass and readout as separate siblings. Preserve the declared sampling bounds and premultiplied-alpha handling. The provided lens looks up the app's default shader library; package/framework adoption needs an explicit shader bundle and its own validation.

Give physics, waveform and spectrum displays honest data/model semantics. Metronome rate, ticker motion, synthesized kernel and tactile pitch mapping are examples, not universal behavior for a different instrument.

## Validate the adopted result

Check the changes relevant to this task: native target compilation, actual material rendering, larger text and accessibility alternatives, held/edge touches during redraw, and anchored content across opposite tilt poses where applicable. Measure frame/scroll coordinates for stillness claims. Assess actual sound, haptics and sensor behavior on hardware when those are part of the requested outcome.

The source's historical tests and the starter's compile checks do not certify a new app. Keep simulator results, installed-device observations and hands-on sensory feedback distinct. Report the concrete design adaptation, checks completed and any remaining acceptance limits.

