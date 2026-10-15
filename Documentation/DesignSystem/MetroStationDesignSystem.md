# Metro Station SwiftUI Design System

**Edition 1.0 · iPhone foundation · Source baseline Metro Station build 14 · October 12, 2026**

Metro Station combines a dark instrument environment, precise metal surfaces, restrained spectral color and native Liquid Glass controls. Its richness comes from calibrated detail, clear material hierarchy and tactile response. The central value stays easy to read while light, refraction, signal traces and mechanical details communicate what the instrument is doing.

Use this system for SwiftUI learning tools, music instruments, scientific visualizations, timers and dashboards that benefit from a strong primary object. Carry the material hierarchy and interaction contracts into a new app; give that app its own quantities, units, clock, vocabulary and feedback meanings.

The current app targets iOS 27. The accompanying starter supports iOS 26 or later with Swift 6 and the current SDK. This is a dark appearance specification. A light appearance requires its own palette and material validation.

[Visual atlas](VisualReference.png) · [Editable vector atlas](VisualReference.svg) · [Starter installation](README.md) · [Token manifest](design-tokens.json)

## 1 What to carry into another app

| Foundation | Reusable rule |
| --- | --- |
| Environment | A near-black blue-green canvas, faint technical grid and localized ambient color establish an instrument setting. |
| Primary object | One large, legible object carries the main task. Opaque metal provides weight and reference geometry. |
| Glass | Native glass belongs to controls and a carefully isolated instrument lens. Content panels remain visually quiet. |
| Typography | Rounded numerals communicate the live value; monospaced labels communicate units and engineering context; occasional serif meaning adds a human register. |
| Color | Cyan identifies active control and continuous signal; amber identifies events and emphasis; violet and magenta distinguish a second signal family. |
| Motion | Motion follows an authoritative state or clock. It supplies information through the instrument’s interior while keeping readouts and controls anchored. |
| Touch | Fine adjustment, semantic adjustment and direct manipulation each have visible and accessible alternatives. A control owns the touch that begins on it. |
| Light | Faint edge reflections move with tilt. The glass face stays clear and text stays unfiltered. |
| Feedback | Visual, audible and tactile cues use the same accepted event. Feedback never creates extra domain events. |

### Essential visual contracts

1. Foreground values, units, semantic labels and control frames remain independent of sensor transforms and optical sampling.
2. Glass opacity stays constant across ordinary ticks. The lens may change radius; its center stays fixed.
3. A highlight follows a small part of the lens perimeter. It adds no broad moving fill over the face.
4. Chromatic separation remains subtle and confined to diagonal edge detail.
5. Pill outlines remain constant while interior energy changes.
6. Whole-number parameters show whole digits. Other domains retain precision when their units require it.
7. Native held Stepper behavior and knob interaction continue while the instrument redraws.
8. Content remains reachable above floating controls and with larger text.

These are design contracts for adoption. They are separate from any particular device test result.

## 2 How to read the tokens

The files in this folder form a small portable kit:

| File | Purpose |
| --- | --- |
| `design-tokens.json` | Machine-readable colors, material values, dimensions, typography, motion and optical tuning. |
| `InstrumentDesignSystem.swift` | Palette and native components: background, panel, icon button, telemetry, Stepper, large readout and isolated glass surface. |
| `InstrumentControlTouchBoundary.swift` | A standalone UIKit bridge that protects the nearest containing UIScrollView pan during an embedded control touch. |
| `LensRefraction.swift` | Portable bounded refraction and diagonal chromatic-weight functions. |
| `InstrumentLensOptics.metal` | One SwiftUI layer shader for underlying decorative ink. |
| `UsageExample.swift` | A complete angle-explorer screen demonstrating the components in another domain. |
| `VisualReference.svg` | Editable color and layer reference; glass drawings in it are schematic. |
| `VisualReference.png` | Rendered visual atlas for quick reference. |
| `README.md` | Starter installation, host responsibilities and validation scope. |
| `validation.json` | Edition checks, content hashes and frozen-source parity. |

The token manifest marks values as **current** or **recommended**. Current values reproduce the build 14 vocabulary. Recommended values consolidate it for a new app. The source still contains component-specific colors and spacing; it does not already implement one completely centralized token library.

Colors expressed as SwiftUI RGB doubles are canonical. Hex strings are nearest 8-bit sRGB approximations. Native material pixels vary with the operating system, surrounding content and accessibility settings.

Points describe layout and shader sampling distance. They do not describe physical millimeters or display pixels. A 1-point red-to-blue split covers different pixel counts on displays with different scale factors.

## 3 Color foundations

### Surfaces and text

| Semantic role | Approximate hex | Canonical RGB | Use |
| --- | --- | --- | --- |
| Canvas | `#060B0F` | 0.025, 0.042, 0.058 | Full-screen environment. |
| Content panel | `#0B1216` | 0.045, 0.070, 0.087 | Signal lab and supporting content. |
| Gauge housing | `#070A0E` | 0.027, 0.041, 0.055 | Opaque primary-object body. |
| Metal light | `#0E1317` | 0.055, 0.073, 0.090 | Upper illuminated metal. |
| Metal dark | `#05080B` | 0.021, 0.032, 0.042 | Recessed metal depth. |
| Plot inset | `#06090C` | 0.022, 0.036, 0.047 | Quiet plotting area inside a panel. |
| Display ink | `#E8F2F7` | 0.91, 0.95, 0.97 | Main numerical value. |
| Secondary ink | `#99B0BA` | 0.60, 0.69, 0.73 | Labels, supporting values and context. |

White opacity is an additional ink system, not a replacement for semantic text colors. Current values include 0.68 for dial metadata, 0.74–0.75 for supporting axes/captions, 0.09 for a panel border and 0.025 for the background grid. Very low-opacity ink is supplementary calibration or decoration.

### Accents and signal families

| Role | Approximate hex | Canonical RGB | Meaning |
| --- | --- | --- | --- |
| Action cyan | `#57EDF5` | 0.34, 0.93, 0.96 | General actions, selected state and main Stepper value. |
| Action amber | `#FFBD5E` | 1.00, 0.74, 0.37 | Active transport and emphasized events. |
| Instrument cyan | `#52E8F5` | 0.32, 0.91, 0.96 | Dial, crown and large waveform markings. |
| Instrument amber | `#FFB84F` | 1.00, 0.72, 0.31 | Dial index, crown and large carrier markings. |
| Wave primary | `#4FDBFF` | 0.31, 0.86, 1.00 | Compact waveform trace. |
| Wave depth | `#3666FF` | 0.21, 0.40, 1.00 | Waveform secondary depth. |
| Spectrum primary | `#C291FF` | 0.76, 0.57, 1.00 | Compact spectrum trace. |
| Spectrum depth | `#F55CD6` | 0.96, 0.36, 0.84 | Spectrum secondary depth. |
| Compact carrier | `#FFBA57` | 1.00, 0.73, 0.34 | Frequency carrier marker. |

Preserve the small action/instrument differences as named variants when matching Metro Station. A new app may deliberately consolidate them, but that is a palette change rather than an exact extraction.

Use color with position, labels, shape or icons. Amber already represents activity in this system; an error needs explicit text and a suitable symbol or native destructive role. Assign a separate domain-specific status palette when warnings, success and destructive actions must coexist.

### Color density

Keep most screen area dark. Apply saturated color to thin traces, small indicators, selected values and primary actions. Large areas of saturated light reduce the metal/glass distinction and compete with the readout.

A useful composition has one continuous-signal family and one complementary event accent. Add the violet/magenta family when a second data channel needs an independent identity. The environment’s cyan wash is atmospheric, so it remains much quieter than an active waveform.

## 4 Typography

The system uses Apple system fonts. The visual contrast comes from three designs with distinct jobs.

| Role | Current recipe | Reuse guidance |
| --- | --- | --- |
| App title | 27 pt, semibold, rounded; one line; minimum scale 0.75 | Preserve clear naming and a compact header. Scale or reflow for longer localized titles. |
| App subtitle | 9 pt, medium, monospaced; tracking 2.6 | Short category label. Prefer scalable 11–12 pt in a new app when it carries useful content. |
| Hero numeral | 0.23 × object diameter, light, rounded; monospaced digits; width 0.64D; minimum scale 0.7 | Make the value dominant and position stable. |
| Hero unit | ScaledMetric base 11 pt relative to caption2, medium, mono; tracking 2.2 | Units stay quieter but visible. Include them in the spoken value. |
| Human meaning | System subheadline, medium serif, italic, instrument cyan | A short interpretation such as Allegro, Resonance or Equilibrium. |
| Phase metadata | ScaledMetric base 11 pt, regular, mono; monospaced digits | Supplementary information with its own fixed position. |
| Stepper label | 10 pt, medium, mono; tracking 1.5 | Starter uses a scalable 11 pt base as an adoption improvement. |
| Stepper value | 18 pt, medium, rounded; monospaced digits | Compact direct-control value; starter makes its size scalable. |
| Telemetry label | Caption2, mono; tracking 1.2 | Metric name. |
| Telemetry value | Title3, mono | Secondary quantity. |
| Telemetry unit | Caption2, mono, first-baseline alignment | Unit remains attached to its quantity. |
| Pill title | ScaledMetric base 10 pt, semibold, mono | WAVE/FREQ-style short channel identifier. |
| Pill axes | ScaledMetric base 9 pt, medium, mono | Supplementary endpoints; provide an accessible description. |
| Explanation title | LargeTitle, rounded, semibold | A separate learning or explanation surface. |
| Equation | Callout, mono | Explicit units and assumptions near the equation. |
| Explanation prose | Subheadline or body | Readable native text rather than dense engraving. |

### Formatting contracts

- Apply `.monospacedDigit()` to values that change in place.
- Reserve value width and label height where repeated input must stay steady.
- Separate the magnitude from the unit in telemetry, using first-baseline alignment.
- Use a fixed precision policy for each quantity. Metro Station renders BPM as an integer, beat rate with two decimals, interval as whole milliseconds and pitch as whole hertz.
- Keep displayed and spoken precision consistent.
- Treat minimum-scale factors as compact-layout fallbacks. At accessibility sizes, reflow supporting content and expose complete values rather than shrinking everything.
- Keep all-caps tracking for short labels. Use sentence case for instructions, explanations and errors.

The current app includes fixed small technical labels. Adopting this visual language does not by itself establish complete Dynamic Type support or readable contrast in every state.

## 5 Spacing and geometry

### Recommended shared spacing

Use a 4-point family for new layout work: **4, 8, 12, 16, 24, 32**. Give spacing a purpose: inline relation, component grouping, panel padding, section separation or screen inset.

Metro Station also uses 3, 5, 6, 7 and 10 points inside compact instruments. Keep those values within their component recipes when matching the source. Avoid creating a global token for every incidental literal.

### Current layout dimensions

| Area | Value |
| --- | --- |
| Portrait screen inset | 12 pt; subsidiary rows add 10 pt. |
| Header | Horizontal 24; top 10; bottom 12. |
| Portrait main stack | 12 pt spacing; maximum content width 540. |
| Landscape composition | Two columns separated by 24; instrument column uses up to 47% of available width. |
| Gauge cluster | Maximum width 490; maximum gauge diameter 360. |
| Pill widths | 30 below cluster width 350; otherwise 36. |
| Pill-to-gauge gap | 6 on each side. |
| Pill height | min(218, 0.66 × gauge diameter). |
| Stepper and crown row | Maximum width 380. |
| Main Stepper | Minimum height 48; horizontal padding 14. |
| Supporting touch target | 44 × 44 minimum design target. |
| Crown metal face | 62 × 62. |
| Content panel | Padding 16; corner radius 22. |
| Plot inset | Corner radius 10. |
| Beat tile | Height 37; corner radius 8; row gap 7. |
| Floating transport | Horizontal inset 22; top 10; bottom 12. |
| Bottom content reserve | 98 pt in the source layout. |

The 98-point reserve belongs to the current transport arrangement. A new app should reserve its actual floating-control footprint plus an appropriate content gap, especially with localization and larger text.

### Gauge cluster calculation

~~~text
clusterWidth = min(availableWidth, 490)
pillWidth = clusterWidth < 350 ? 30 : 36
D = min(360, clusterWidth − 2×pillWidth − 12)
pillHeight = min(218, 0.66×D)
clusterWidthUsed = D + 2×pillWidth + 12
~~~

On the tested 430-point-wide iPhone layout, the dial is 322 points. Use proportional geometry inside it; do not scatter independent absolute positions through a resizable instrument.

## 6 Materials and elevation

### Material hierarchy

| Surface | Visual recipe | Job |
| --- | --- | --- |
| Environment | Solid canvas + localized cyan wash + faint grid | Establishes place and depth without competing with content. |
| Content panel | Panel color at 0.85; radius 22; white 0.09 border at 1 pt | Houses charts, explanations and supporting information. |
| Instrument housing | Opaque blue-black metal; calibrated rim; recessed face | Gives the primary object weight and stable reference geometry. |
| Native control glass | Regular native glass, sometimes gently tinted and interactive | Identifies an actionable, floating control. |
| Native lens | Clear native glass at constant 0.48 composite opacity | Provides an optical instrument layer over decorative metal. |
| Plot inset | Quiet near-black surface; radius 10; white 0.075 border at 0.6 pt | Holds readable data marks. |
| Pill enclosure | Opaque dark gradient; static capsule border | Contains a compact signal channel. |

Apply native `glassEffect` after sizing and appearance modifiers. Use `GlassEffectContainer` for nearby glass controls, and tune its spacing in relation to the actual row spacing. A container can merge neighboring effects; keep grouping deliberate. Native button styles supply standard action treatment. [Apple custom Liquid Glass guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

### Environment recipe

- Background RGB: 0.025, 0.042, 0.058.
- Ambient wash: action cyan at opacity 0.085; top-trailing center; radii 5–620 pt.
- Grid: 28-point spacing, white 0.025, 0.5-point stroke.
- Background ignores safe areas and is hidden from accessibility.
- Decorative background content does not own touches.

The starter suppresses its ambient wash under Reduce Transparency as an adoption improvement. The source background’s wash is always present.

### Metal recipe

The housing uses a black 0.8 shadow with radius 22 and y offset 16. Its 1.4-point outer rim transitions through white 0.36, white 0.025, black and white 0.15. The recessed face is inset by 0.038D, with a white 0.07 stroke at 0.6 pt.

Metal detail is strongest at boundaries, grooves, calibration marks and bearings. Broad face regions remain dark. Use directional light to explain surface shape, not to paint every object with a bright glow.

The crown uses a smaller black 0.75 shadow: resting radius 6/y 5, pressed radius 3/y 2. Its inner metal gradients, 40 knurls and concentric grooves distinguish it from the smooth native glass controls beside it.

### Light recipe

The accepted reflection is a faint rim arc:

~~~text
lensRadius = 0.38 × D × radiusScale
arcRadius = 0.985 × lensRadius
arcCenterAngle = −90° + 70°×enhancedTilt.x + 20°×enhancedTilt.y
arcSpan = 76°
strokeWidth = 0.9 pt
gradient = clear → white at opacity 0.085 → clear
~~~

The reflection’s angular position follows tilt. Its peak opacity stays constant. The center remains free of broad highlight fills, moving oval patches and bloom. The glass’s native material still provides its own optical response.

## 7 Layer architecture

Treat an instrument as a stack of independently owned layers:

~~~mermaid
flowchart BT
    A["Environment and grid"] --> B["Opaque housing and recessed metal"]
    B --> C["Decorative Canvas with calibration and moving mechanism"]
    C --> D["Canvas only refraction and chromatic sampling"]
    D --> E["Centered native clear glass"]
    E --> F["Faint perimeter reflection"]
    F --> G["Unfiltered value units and semantic meaning"]
    G --> H["Fixed interaction region"]
~~~

The shader filters only decorative SwiftUI drawing content. The native glass, foreground text and controls remain separate siblings. `layerEffect` requires a bound for the maximum sampling distance on each axis; UIKit/AppKit-backed views are not reliable filtered content. [Apple layerEffect documentation](https://developer.apple.com/documentation/swiftui/view/layereffect(_:maxsampleoffset:isenabled:))

A second architecture separates presentation updates from interaction identity:

~~~mermaid
flowchart LR
    S["Domain model and acknowledged state"] --> P["Presentation snapshot"]
    P --> V["Timeline driven instrument drawing"]
    S --> C["Persistent native controls"]
    C --> R["Requested change"]
    R --> S
    M["Bounded motion service"] --> V
    V --> T["Readout at fixed coordinates"]
~~~

Assign each visual quantity a state owner. Requested values can update immediately; phase and evidence of output must follow the authoritative rendered state. Metro Station uses this division:

| Visual quantity | Current owner | Reusable implication |
| --- | --- | --- |
| Hero BPM, musical marking and amber tempo index | Requested settings | Make the user's accepted edit visible immediately. |
| Ticker phase | Presented renderer snapshot | Preserve the clock's accumulated phase during edits. |
| Actual tick metadata, pill energy and signal shape | Published tick/render state | Depict the event that actually occurred, using its own kernel and timing. |
| Lower frequency and interval telemetry | Effective settings in the presented snapshot | Describe the active renderer, rather than implying an unacknowledged change is already sounding. |
| Lens bounce | Presented phase with amplitude derived from requested BPM | Keep its center fixed; distinguish phase continuity from amplitude continuity during a large rate change. |

The last row is current tuning, not a guarantee of continuous amplitude across all edits. A new app can interpolate decorative amplitude separately if that communicates its domain better. When requested and effective values differ, reserve a constant-height status row for acknowledgement text. Metro Station displays APPLYING SETTINGS in its existing footer while a requested change awaits acknowledgement; carry the stable-row pattern into an adopting app.

Keep the Stepper and crowns outside the animation TimelineView. Give each sensor, renderer and controller a clear lifecycle owner at the screen or app-model level.

## 8 Primary instrument component

### Anatomy

A primary object contains:

1. A housing and inset face.
2. Calibration marks, a range or scale, and an index.
3. A mechanism or visualization tied to the domain.
4. A dominant numerical readout.
5. Units and a short human interpretation.
6. Optional secondary phase or state metadata.
7. A fixed interaction region and accessible adjustment actions.

Metro Station’s calibration radius is 0.445D. Its central number sits at y 0.52D, units at 0.665D, musical meaning at 0.745D and phase at 0.835D. All x positions are centered.

At accessibility text sizes, the source hides supplemental unit/phase lettering and moves the meaning to y 0.79D. Spoken values retain the essential context. A new app with more complex values may replace the decorative gauge readout with a larger adjacent native text block.

### Mechanism tuning

The metronome ticker pivots at y 0.38D and has length 0.235D. A sliding weight sits at 58% of the arm. It rests upright at 0° and swings ±26°, with a full arm cycle spanning two quarter-note beats.

These values communicate a metronome. For a voltmeter, orbital model, compass or queue monitor, choose a mechanism that matches its quantity and use the same stable layer architecture.

### Interaction

Rim scrubbing begins outside radius 0.30D. The center readout remains calm. Angular travel is accumulated incrementally across the ±π seam, rather than mapped to an absolute angle at first touch.

Provide non-gesture alternatives: an adjacent native Stepper, accessible adjustable actions, and useful named increments. Direct manipulation is an affordance, not the only input path.

## 9 Native Stepper component

The Stepper sits immediately under the hero, making repeated adjustment visible beside its result.

Its anatomy is a short engineering label, a rounded monospaced-digit value with units, and the native minus/plus control inside a dark capsule. The source uses a 48-point minimum height, 14-point horizontal padding, panel opacity 0.85 and cyan 0.14 border at 1 pt.

### Behavioral contract

- Native press-and-hold repeat remains active during animation and value changes.
- An accepted increment or decrement updates the domain once and emits its associated feedback once.
- Clamp at domain limits. An unchanged target creates no extra event.
- Keep the control’s view identity stable while the instrument redraws.
- Protect the entire native button bounds, including top and bottom edges.
- A touch beginning on the Stepper belongs to the Stepper for the complete sequence.
- Touches beginning elsewhere may scroll the page.

The supplied UIKit bridge protects the nearest containing UIScrollView pan. It preserves native child-control handling and does not cancel touches. Higher nested scroll views and a presentation sheet's dismissal gesture need separate host validation; the helper does not establish a global gesture guarantee.

The starter is an integer Stepper. A quantity requiring decimals should use a valid domain step and a deliberately chosen formatter. The whole-BPM rule is not a prohibition on decimals in unrelated applications.

## 10 Tactile crown component

The crown expresses adjustment through knurling, a bearing, a clear top label and explicit plus/minus alternatives.

Two adjustment roles create useful hierarchy:

| Role | Metro Station tuning | Reusable meaning |
| --- | --- | --- |
| Fine | 8° detents; one BPM per accepted step | Small increments in a physical or numeric parameter. |
| Semantic | 20° detents; next/previous tempo band | Jump between meaningful states, presets or scales. |

Direction reversal requires deliberate travel. Current hysteresis is 18% of the detent spacing: 1.44° for fine and 3.6° for semantic steps. The center has a 7-point exclusion radius to avoid angular singularity. First touch initializes history without changing the value.

The gesture tracker emits at most one step per update. Large pointer jumps retain fractional travel but do not produce a queue of catch-up notches. Output is capped at 20 events per second, and pending direction is cleared on meaningful reversal.

### Appearance

- Metal face: 62 × 62 pt.
- Neighbor buttons: actual 44 × 44 framed labels.
- Symbol: 13 pt semibold.
- Native circular glass: regular, interactive, accent tint opacity 0.08.
- Top and bottom caption rows reserve a scaled 14-point base height.
- Captions remain steady as a semantic label changes.
- Accessibility sizes arrange the two crowns vertically.

The crown is a specialized component, not a mandatory control for every screen. Use it where continuous exploration and tactile increments improve the task.

## 11 Vertical signal pill component

A pill is a compact instrument with a stable enclosure:

~~~text
short channel title
upper endpoint
vertical trace region
lower endpoint
~~~

The source uses horizontal padding 5, vertical padding 10, internal gaps 3, width 30 or 36 in the cluster and height min(218, 0.66D).

The enclosure gradient runs left to right from RGB 0.055/0.069/0.095 to 0.014/0.022/0.037. Its 0.8-point capsule outline is static: primary opacity 0.36, white 0.10, secondary 0.38. Increased Contrast raises the primary outline contribution to 0.70.

### Signal semantics

Wave time runs downward from 0 to 55 ms. Amplitude runs horizontally. Spectrum frequency runs upward from 0 to 6 kHz, with an amber carrier marker. These axis directions are intentional and should be explained in the accessible value.

A quiet reference trace remains visible. Interior ribbons, stroke thickness and energy geometry react to the accepted tick, with a clear attack and decay. The outer capsule, title positions and touch/layout frame stay constant.

For another app, a pill can show a short pressure history, current trace, normalized distribution or event envelope. Provide the actual units, direction, normalization and data provenance for that channel.

### Motion tuning

Metro Station’s perceptual envelope has support min(200 ms, 0.8 × actual pulse interval). Attack is min(20 ms, support/4), followed by a smooth decay. Strength includes a square-root mapping of the strongest relevant audible/haptic event strength.

This envelope is a visual cue. It does not extend the 55 ms audio tick or measure actuator intensity. Reuse its bounded attack/decay structure; retune its duration for the domain.

## 12 Supporting components

### Telemetry row

Three equal columns carry a label, value and unit. Dividers are 1 × 30 pt at white 0.10. Each metric is one accessible element with a complete spoken value.

Keep secondary telemetry below the direct controls. Its cadence can be lower than the hero’s motion because stable values benefit from readable updates.

### Event or beat tiles

The source tiles are 37 pt high, radius 8, with row spacing 7. Active fill is cyan 0.08 and border cyan 0.35. Idle fill is white 0.025 and border white 0.06. Subdivision markers are 2-point-high capsules.

Reuse this grammar for discrete event position, staged processing or a small finite sequence. Keep selected state clear through number and position as well as color.

### Signal lab panel

A quiet content panel houses a native segmented Picker, carrier metadata, plot and explanation. The normal scope height is 140 pt; at accessibility sizes the fixed outer height is removed and metadata stacks.

Plot axes must identify units. A normalized spectrum must say that it is normalized. A synthesized model must not be labeled as a microphone measurement.

### Floating action group

The transport is native glass over the page. It has no black backing strip.

Current label frames are 62 × 58 for Tap, a flexible primary action with minimum height 58, and 54 × 58 for settings. Row spacing is 12; glass-container spacing is 14. The primary action is prominent, cyan when stopped and amber when running.

These are label-frame values. Native style padding can enlarge rendered glass bounds. Measure the actual surface and hit region rather than treating the label frame as the outer material size.

Use one clear primary action, with secondary context controls to its sides. Reserve enough content space for the last row to remain reachable.

### Settings and explanations

Settings use native NavigationStack, Form, sections, toggles, sliders, Pickers and a Done action. The source presents instrument settings in a full-screen cover and explanations in a sheet.

Choose presentation for the task. Where direct manipulation conflicts with an interactive-dismiss gesture, resolve that ownership deliberately. Explain quantities and model limits in a separate readable surface rather than overloading the instrument face with implementation detail.

## 13 Motion and sensor system

Motion has three distinct purposes:

| Purpose | Example | Ownership |
| --- | --- | --- |
| Domain motion | Ticker phase, event position or measured trace | Authoritative domain state. |
| Material response | Tilt reflections, refraction, edge color | Bounded presentation inputs. |
| Interaction response | Crown rotation and pressed depth | The active control gesture. |

Keep these purposes independent. A tilt is not a domain-value edit. A pressed control is not an instruction to restart the domain clock.

### Sensor baseline

The current portrait mapping uses device gravity X for visual horizontal input and gravity Z for visual vertical input:

~~~text
targetX = clamp(1.7 × (gravity.x − referenceX), −1, 1)
targetY = clamp(1.7 × (gravity.z − referenceZ), −1, 1)
filtered += 0.18 × (target − filtered)
~~~

The service samples at 30 Hz and captures a fixed reference when starting. Holding a tilt preserves its visual response. Stopping resets the outputs.

The current mapping is not remapped to landscape screen axes. A new app supporting rotation must map sensor coordinates into the current interface orientation and deliberately rebase when that orientation changes. Give each sensor run a generation identifier so stale queued callbacks cannot affect a restarted stream.

### Sampling and updates

The source requests 60 Hz for the gauge/pills and 30 Hz for lower telemetry. Reduce Motion uses a 10 Hz timeline request, with the main motion effects disabled. Timeline scheduling is a request, not a guarantee of every frame.

Pause animation timelines outside an active scene or when their domain is idle. Keep expensive trace generation off the main actor, and cache by the parameters that actually alter the trace.

### Lens bounce

The metronome lens samples one analytic, damped radius curve from preserved beat phase. It does not run a separate accumulating UI timer. Radius, velocity and acceleration meet continuously at beat wrap.

At its fastest tuning, the designed outward scale reaches 1.09, compresses to about 0.95402 and makes a small settling rebound. Its center remains fixed. The precise damping and BPM-amplitude relationship belong to the metronome; another app should define motion appropriate to its state.

For one-shot transitions, use an appropriate native spring. For continuously advancing domain motion, sample the domain’s phase and avoid repeatedly restarting implicit animations.

## 14 Optical rendering recipe

The lens uses native clear glass. Additional optics apply to the decorative face beneath it.

### Bounded tilt

Radially clamp input g to the unit disk, preserving its direction. Enhance moderate input:

~~~text
e = 2g / (1 + |g|²)
~~~

The resulting magnitude stays at most one. Disabled or nonfinite input produces zero custom displacement.

### Achromatic refraction

Let D be gauge diameter in points, R the actual lens radius, and r the distance from lens center divided by R. Let S(t) = 6t⁵ − 15t⁴ + 10t³.

~~~text
maximumShift = min(9.5 pt, 0.025 × D)
feather = 1 − S(clamp((r − 0.82)/0.18, 0, 1))
weight = feather × (1 − 0.32r²)
offset = e × maximumShift × weight
sourcePosition = destinationPosition − offset
~~~

The shader returns the original sample at and outside the lens rim. The feather has continuous first and second derivatives at its joins. At D=322 pt, maximum displacement is 8.05 pt.

### Diagonal chromatic separation

~~~text
window =
  S((r − 0.52)/0.30)       for 0.52 < r < 0.82
  1 − S((r − 0.82)/0.18)  for 0.82 ≤ r < 1
  0                       elsewhere

diagonalWeight = (2xy/r²)²
totalSplit = min(1.2 pt, D/322)
channelOffset = e × 0.5 × totalSplit × window × diagonalWeight
~~~

Coordinates x/y are lens-local, normalized by radius. Red samples at base+channelOffset, green at base and blue at base−channelOffset. Total red-to-blue separation is at most 1 pt at a 322-point diameter. Center, axial arcs and rim have zero custom color separation.

This is a restrained artistic cue, not a calibrated wavelength or refractive-index simulation.

### Compositing requirements

- Use one layerEffect for the combined sampling; avoid stacking an independent warp and an independent chromatic pass.
- Keep the native glass and text outside that filtered layer.
- Include `<SwiftUI/SwiftUI.h>` in the Metal file.
- Layer samples are already premultiplied RGBA. Select red/green/blue components without multiplying them by alpha again.
- For the current SDR ink, use the maximum of the three sample alphas and bound selected RGB by that alpha.
- Declare each-axis maximum sampling distance as maximumShift + half the total channel split: 8.55 pt at D=322.
- Return identity samples outside the lens.
- Revisit compositing if the host introduces HDR/emissive values beyond the current SDR assumptions.

The shader’s signature and sample behavior follow Apple’s layer-effect API. [Apple shader sampling reference](https://developer.apple.com/documentation/swiftui/view/layereffect(_:maxsampleoffset:isenabled:))

## 15 Tactile and audible feedback

### Detent vocabulary

| Accepted event | Current intensity | Current sharpness |
| --- | --- | --- |
| Fine upward | 0.78 | 0.95 |
| Fine downward | 0.82 | 0.20 |
| Semantic upward | 1.00 | 0.60 |
| Semantic downward | 1.00 | 0.05 |

These are Metro Station’s Core Haptics tuning values. Perceived strength varies by hardware and context. Carry the distinction between fine, semantic and directional feedback into a new app, then test its own tuning.

Prewarm and cache players. Emit feedback for accepted changes, cap event density and skip obsolete queued feedback rather than producing bursts. Keep repetitive domain pulses separate from adjustment detents.

### Audio and clock contracts

A high-rate instrument should preserve its accumulated phase when its rate changes. Existing audio tails retain their original pitch/envelope. Parameter changes reach the active graph at a render boundary, with gain ramping where needed.

Keep real-time callbacks bounded and free from main-actor work, locks and repeated array allocation. Derive sounded-event displays, pulse scheduling and active-renderer telemetry from acknowledged output state. Requested-value readouts may update immediately according to the ownership table in section 7. Haptic scheduling has a separate hardware clock and must be calibrated where tight synchronization matters.

The phone does not expose arbitrary actuator carrier-frequency control. Metro Station maps pitch to sharpness using a logarithmic range, while audible pitch remains the selected frequency. A tactile description must identify what is encoded rather than claiming that audio and actuator frequencies are identical.

Headphones, Bluetooth, speaker output, display and haptic hardware add their own latency. Visual coherence is a design goal; zero physical output delay is not a valid general promise.

## 16 State and feedback matrix

| State | Main value and controls | Drawing | Material and feedback |
| --- | --- | --- | --- |
| Idle | Stable value; controls usable | Quiet reference or rest state | Lens at rest; material may respond to enabled tilt. |
| Armed | Show meaningful readiness | Domain waits for its acknowledged start | Keep the action available; avoid a fake pulse. |
| Running | Value stays anchored | Phase and interior signal follow the source clock | Native action becomes Stop; event emphasis may be amber. |
| Editing | Requested value appears immediately | Authoritative phase continues; requested-value indicators may change | Native hold survives; accepted detents supply feedback. |
| Applying | Reserve a constant-height status row | Output-derived drawing follows acknowledged state | No engine restart or catch-up feedback burst. |
| Domain limit | Show the valid boundary | Normal drawing continues | Disable invalid action or reject it without extra value events. |
| Interrupted | Explain why the task paused | Freeze or show a meaningful rest state | Resume requires an explicit user action where appropriate. |
| Motion unavailable/off | Domain controls remain functional | Domain animation may continue | Disable custom tilt optics and show a useful static surface. |
| Inactive scene | Preserve appropriate domain state | Pause presentation scheduling | Stop unnecessary sensor work and follow host audio policy. |
| Error | Readable text and recovery action | Preserve trustworthy data or a clear empty state | Use semantic error treatment rather than color alone. |

Define domain-specific transitions explicitly. A music instrument’s foreground playback policy should not be copied automatically into a background timer or another app with different requirements.

## 17 Accessibility and inclusive use

Treat accessibility as part of each component’s contract. Native material behavior and settings need scenario checks on the target OS. [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)

| Setting or need | Required adoption behavior |
| --- | --- |
| Reduce Motion | Freeze optional lens/ticker motion; stop sensor-driven decoration; disable custom distortion, chromatic splitting and rim glide; retain usable semantic controls and static references. |
| Reduce Transparency | Suppress custom optics/hazy lighting; restore full native lens material opacity; use opaque content panels where readability requires them. |
| Increased Contrast | Strengthen boundary cues and verify real content contrast. The source explicitly increases pill borders; the starter also strengthens panel borders. |
| Dynamic Type | Scale useful text, reserve enough label height, stack dense rows and remove decorative metadata before shrinking essential values. |
| VoiceOver | Speak label, complete value, unit and state. Expose adjustable actions and useful named increments. Hide decorative paths and redundant engravings. |
| Color differentiation | Pair color with labels, icons, position or shape. |
| Photosensitivity and comfort | Keep enclosure borders constant; avoid global brightness pulses and flashing outlines; provide static presentation through Reduce Motion. |
| Motor access | Offer native +/- alternatives to knobs and rim gestures. Protect full touch targets and control edges. |
| Localization | Allow longer names, localized digits/units and sufficient action width. Keep physical clockwise/counterclockwise behavior explicit and separate from text direction. |

A custom instrument face needs an accessible value even when its pixels are drawn in Canvas. Do not announce every animation frame. Announce useful accepted changes or let the person query the current state.

The starter preserves the source’s geometric hero numeral. For apps where large text is essential, supply a scalable adjacent readout or a simpler accessibility presentation instead of forcing large content into the lens.

Color tokens and low opacity do not constitute contrast certification. Validate actual composited content against its changing backdrop.

## 18 SwiftUI implementation recipes

### Native glass control

Size the actual label before applying the material:

~~~swift
Button(action: action) {
    Image(systemName: "plus")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(InstrumentPalette.instrumentCyan)
        .frame(width: 44, height: 44)
        .glassEffect(
            .regular.tint(InstrumentPalette.instrumentCyan.opacity(0.08)).interactive(),
            in: .circle
        )
}
.buttonStyle(.plain)
.accessibilityLabel("Increase value")
.instrumentControlOwnsTouches(identifier: "fineIncrement")
~~~

Group neighboring glass controls inside one deliberate GlassEffectContainer. The container’s spacing affects how effects combine; it is not simply an HStack gap. [Apple GlassEffectContainer reference](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)

### Stable integer parameter

~~~swift
InstrumentParameterStepper(
    "ANGLE",
    value: $angle,
    in: 0...180,
    unit: "°",
    onEditingChanged: { editing in
        // Begin/end domain editing or persistence deferral here.
    },
    onAcceptedChange: { acceptedValue in
        // The Binding already holds acceptedValue.
        // Emit feedback or update dependent work here; do not write it again.
    }
)
.frame(maxWidth: 380)
~~~

The host owns valid initial state and any non-integer domain policy. This component keeps native held repeat outside the instrument's animation timeline.

The Binding owns the value write. If its setter also sends a domain command, do not send the same command again from onAcceptedChange. That callback is a post-write notification for feedback or other dependent work.

### Layered optical surface

~~~swift
InstrumentLensSurface(
    diameter: diameter,
    radiusScale: presentation.radiusScale,
    filteredTilt: motion.screenSpaceVector,
    motionActive: motion.isActive
) {
    // Pure SwiftUI decorative face, preferably Canvas or Shapes.
    // Draw calibration and a domain mechanism here.
    MetalFaceDrawing(snapshot: presentation.snapshot)
} readout: {
    InstrumentLargeReadout(
        diameter: diameter,
        value: formattedValue,
        unit: unitLabel,
        meaning: meaningLabel,
        spokenLabel: quantityName
    )
}
~~~

This is a host-integration recipe: the named presentation and motion values belong to the adopting app. InstrumentLensSurface owns presentation layers, not a sensor permission prompt, domain clock or dial gesture. Place any interactive dial hit region outside the optical filter, with fixed geometry.

### Source state ownership

~~~swift
@State private var model = DomainController()
@State private var motion = ScreenMotionService()

// A sampled drawing uses a snapshot.
// Persistent controls use action closures and stable identity.
// Do not create a controller or motion manager inside a Canvas render closure.
~~~

The code above describes ownership; DomainController and ScreenMotionService are host types. The accompanying Swift files provide the reusable visual primitives.

### Installation into a new project

1. Add all four Swift files in this folder to the app target: InstrumentDesignSystem, InstrumentControlTouchBoundary, LensRefraction and UsageExample.
2. Add InstrumentLensOptics.metal to the same target so Xcode compiles it into the default shader library.
3. Target iOS 26 or later for the starter’s native glass components. The source app uses iOS 27.
4. Replace the UsageExample screen with your own domain screen and state model.
5. Supply a filtered vector in current screen coordinates if adopting tilt. Add the relevant motion usage description and lifecycle handling.
6. Connect accepted adjustment events to your domain and feedback engine.
7. Keep persistent controls outside high-frequency drawing timelines.
8. Validate native rendering, touch ownership and accessibility on the actual destination app/device.

For an older deployment target, gate native glass with availability checks and provide a deliberate solid-content fallback. The starter itself does not implement a pre-iOS-26 theme.

## 19 Adaptation recipes

| App family | Primary object | Fine and semantic controls | Compact channels | Human meaning |
| --- | --- | --- | --- | --- |
| Electrical learning | Circuit or calibrated electrical instrument | Component value / component family | Current trace / spectrum or impedance | Resonance, charging, stable. |
| Mathematics | Manipulable geometric or numerical model | Parameter step / named construction | Residual / convergence or distribution | Converging, symmetric, critical. |
| Music and audio | Oscillator, transport or meter | Tuning increment / scale or preset | Wave / spectrum | Register, articulation, harmonic role. |
| Physics visualization | Coordinate instrument or model | Quantity step / regime or scenario | State history / energy distribution | Bound, oscillating, equilibrium. |
| Timer or process tool | Clock or process ring | Duration step / stage or preset | Progress history / event density | Ready, active, complete. |
| Analytical dashboard | Clear hero metric and supporting plots | Threshold step / time range or scenario | Trend / distribution | Stable, changing, outside range. |

Use the semantics of the new data. A dashboard should not bounce every poll merely because the metronome lens bounces on a beat. A scientific plot needs meaningful axes and source assumptions. A simulated trace should identify its model.

### Adoption sequence

Start with the palette, native typography and quiet content panel. Establish one primary object and its large stable value. Add direct controls and useful feedback. Add compact channels only when they communicate independent information. Finally add bounded material response, preserving readable content and touch ownership.

### New component review questions

- What does its material say about whether it is content, instrument or control?
- What value or state does its motion encode?
- Which layer stays fixed while the drawing changes?
- What accepted event creates feedback?
- Can a person use it without the custom gesture, color distinction or motion?
- What quantity, units and model assumptions are visible?
- Does its native glass grouping remain efficient and understandable?

## 20 Performance and verification

### Engineering constraints

Keep real-time domain work separate from presentation. A drawing should consume a prepared snapshot. Cache expensive waveforms, transforms and spectra off the main actor. Recompute when source parameters change rather than on every tempo or UI refresh.

Keep optical shader work to the required decorative layer. Use bounded sampling and limit simultaneous native glass effects. Pause idle/inactive timelines. Do not hide a state mutation, allocation-heavy computation or engine restart inside a visual render closure.

Native glass rendering and multiple effect containers have real costs; tune the scene in the context of its full task. [Apple Liquid Glass performance guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

### Acceptance matrix for an adopting app

| Scenario | Inspect |
| --- | --- |
| Held increment/decrement during active rendering | Value changes correctly; controls keep identity; page and control frame remain steady. |
| Knob rotation and reversal | Correct direction, bounded detents, no seam jump, no queued burst, no ancestor scroll. |
| Control edge touches | Full framed native control remains protected. |
| Modest opposite tilts | Edge/refraction response changes; readout and controls remain at the same coordinates. |
| Motion off and Reduce Motion | Static presentation remains informative and controls remain usable. |
| Reduce Transparency and Increased Contrast | Actual text, calibration and material boundaries remain readable. |
| Accessibility Dynamic Type | Values remain complete; supporting rows reflow and content is reachable. |
| VoiceOver | Controls have meaningful labels, values, actions and stable focus. |
| Long values and localization | Layout holds through changing digit count and longer labels. |
| Inactive/active transition | Timelines and sensors have a correct lifecycle; stale callbacks cannot restart old work. |
| Audio/haptic interruption where relevant | Honest paused/recovery state and clean continuation policy. |
| Actual hardware feedback | Perceived intensity, delay, notch distinction and speaker/accessory sound are assessed directly. |

For visual comparisons, hold the same domain phase and scale across poses. Keep readout, control and outer-reference regions separate from the optical inspection area. A still-image comparison establishes sampled states, not continuous frame pacing.

For touch tests, record content offset and control-window coordinates while the actual native contact is held. Sparse samples do not prove every sub-frame position. Capture engine PCM separately from acoustic listening and haptic perception.

### Metro Station evidence boundary

Build 14 has 51 passing portable tests and a passing physical Stepper-edge scenario with 27.9 seconds of engine PCM, 56 complete ticks, four tempo edits and zero checked faults. Its edge-contact trace has zero sampled offset or marker drift.

The final held-playback and full visual-stillness attempts did not pass; a whole-content shift of 3.6667 points was observed in one visual capture and remains unexplained. The native build 14 images establish the accepted clear-face/rim-only appearance, not a complete stillness or live-sensor certification. The user chose hands-on delivery before further automation. Build 12’s successful real-motion poses are historical evidence.

These limits matter when deciding what to retest in a new app. Source layering and a token manifest are design/implementation contracts, not a universal hardware guarantee. Detailed records remain in the app’s Documentation/QA.md.

### Starter edition validation

All four portable Swift files type-check together in Swift 6 for an arm64 iOS 26 deployment target using the iOS 27 SDK. The portable Metal shader compiles and links with the installed Apple toolchain. All 25 RGB/hex token pairs agree with the declared nearest-8-bit conversion. The editable SVG is XML-valid, and its 1200 × 1900 PNG has been visually inspected for clipping and overlap.

The 49 frozen build-14 app source/configuration files remain unchanged. This edition adds documentation and a separate visual starter; it does not constitute a new installed-app runtime, accessibility or hardware certification. The example needs validation in its adopting app. File hashes and the check scope are recorded in validation.json.

## 21 Metronome specific appendix

Keep these values in a domain adapter rather than the reusable visual foundation:

| Quantity | Source behavior |
| --- | --- |
| Tempo | Whole BPM, 30–240. |
| Tempo meanings | Largo below 60; Adagio 60–75; Andante 76–107; Moderato 108–119; Allegro 120–167; Presto 168–199; Prestissimo from 200. Approximate practice ranges. |
| Semantic step boundaries | 30, 60, 76, 108, 120, 168, 200. |
| Beat | Quarter note; beat frequency BPM/60; period 60/BPM seconds. |
| Ticker | Two-beat cycle; ±26°; upright rest. |
| Lens motion | One analytic damped radius oscillation per preserved quarter-note phase. |
| Audio kernel | 55 ms; 1.5 ms attack; decay; final 7 ms taper. |
| Pulse gains | 1 / 0.72 / 0.36 for downbeat / beat / subdivision. |
| Spectrum | DFT of the isolated synthesis kernel at 48 kHz, 4096 samples, 512 displayed bins. |
| Haptic pitch encoding | Logarithmic sharpness over 220–1760 Hz; no arbitrary actuator-frequency claim. |
| Playback lifecycle | Foreground task; stop on relevant scene/audio interruption or output loss. |

Zero padding improves displayed bin spacing, not physical spectral resolving power. The compact channels depict a synthesis model rather than a microphone or the FFT of the complete overlapping pulse train.

### Source spring formula

Let p be preserved beat phase and b whole BPM:

~~~text
A(b) = 0.70 + 0.30 × (b − 30)/210

q(p) = exp(−1.2p)
       × (1 − exp(−12p))²
       × (1 − smootherstep(p))
       × sin(3πp)

radiusScale =
  clamp(1 + 0.09 × A(b) × q(p)/0.5982974279225974,
        0.92, 1.09)
~~~

The outward peak is near p=0.1803924; dominant compression is near p=0.4549894. Stopped, inactive or Reduce Motion presentation rests at scale 1. This is designed motion, not a mechanical escapement or measured spring simulation.

## 22 Source and maintenance map

Paths below are relative to the Metro Station project root.

| Source | Responsibility |
| --- | --- |
| `App/Views/MetroStationTheme.swift` | Environment, root palette and content-panel recipe. |
| `App/Views/InstrumentView.swift` | Screen composition, cluster sizing, typography, stable Stepper, timelines and floating actions. |
| `App/Views/GaugeView.swift` | Metal gauge, ticker, fixed readout coordinates, native lens and final rim-only light. |
| `App/Views/TempoCrownsView.swift` | Metal crowns, native glass +/- controls, gesture/output behavior. |
| `App/Views/MetroStationPillView.swift` | Compact wave/spectrum channels, static outlines and interior envelope. |
| `App/Views/SignalScopeView.swift` | Larger plotting surface, axes, data provenance and accessibility text. |
| `App/Views/ScrollGestureBoundary.swift` | Production touch ownership and DEBUG audit hooks. |
| `App/Services/MotionLighting.swift` | Current gravity mapping and lifecycle. |
| `App/Services/MetronomeController.swift` | Domain actions, accepted feedback and hardware-state coordination. |
| `Sources/MetronomeCore/LensRefraction.swift` | Bounded optical model. |
| `Sources/MetronomeCore/GlassDialMotion.swift` | Metronome-specific continuous radius curve. |
| `Sources/MetronomeCore/CrownDetentTracker.swift` | Detent tracking and direction hysteresis. |
| `Sources/MetronomeCore/PillTickResponse.swift` | Perceptual visual attack/decay. |
| `App/Shaders/LensRefraction.metal` | Source one-pass optical shader. |
| `Documentation/QA.md` | Exact build/device evidence and limitations. |

When adapting the kit, keep palette changes, domain changes and optical changes reviewable separately. Version the token manifest when altering a semantic role or behavioral contract. Validate the new screen’s own device, accessibility, sensor orientation and feedback behavior.

The accompanying starter retains the current material and optical vocabulary while adding small reusable hardening: scalable Stepper captions/value, accessibility-size label stacking, opaque content panels under Reduce Transparency, strengthened panel borders under Increased Contrast, finite geometry bounds and removal of app-only DEBUG audit dependencies from the touch bridge. It supplies no metronome controller, audio graph, sensor manager or physical-feedback guarantee.

