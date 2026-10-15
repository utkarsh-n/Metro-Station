# Metro Station — waveform metronome

A native SwiftUI instrument for iPhone, targeting iOS 27. The metal dashboard gauge combines calibrated tempo adjustment, beat phase, synthesized ticks, Core Haptics, and gravity driven lighting. Home Screen name: **Metro Station**. The existing bundle ID, `com.utkarsh.spectralmetronome`, and saved-preference keys are retained so the renamed app updates the same installation and preserves its settings.

## Playing

- Press **Start clock**. All tempo inputs and saved settings use **whole BPM**. Drag the rim, or tap **TAP** repeatedly to learn your rhythm.
- Hold the main **TEMPO** stepper's minus/plus actions to repeat one-BPM adjustments while watching the gauge.
- Two knurled watch crowns sit below the gauge. The left **1 BPM** crown gives precise single steps; the right **TEMPO** crown jumps between musical tempo markings. Turn clockwise to increase, counterclockwise to decrease, or tap the crown's minus/plus buttons. Crisp versus deeper single notches distinguish direction; marking jumps feel heavier.
- A second dial of native **clear Liquid Glass** sits centered above the metal face and below the readout. A constant lighter opacity makes the metal and ticker clearer through the lens. Its radius swells, compresses and makes a small settling rebound once per quarter-note beat; faster tempos move faster and gently increase the excursion. Its center, text and touch area stay fixed. Reduce Motion holds it at rest, and Reduce Transparency retains the full native material.
- The metal ticker has a longer arm and a lower bearing. It rests upright at 0° and swings ±26° while running, reaching alternating endpoints on each quarter note tick. Its full cycle takes two beats. The gauge names the tempo, from Largo through Prestissimo, using approximate practice ranges.
- Choose 1–12 quarter note beats per bar and 1–4 pulses per beat. The first beat has a stronger accent. Eighth and sixteenth subdivisions support swing.
- The cyan **WAVE** pill to the left plots the isolated tick over 55 ms; the violet **FREQ** pill to the right plots its normalized spectrum from 0–6 kHz, with an amber carrier marker. Their interiors use a smooth, brief attack and decay from rendered-tick timing, while their outlines stay constant. Switch **Wave / Spectrum** in the lower signal lab for larger plots and attack, decay, taper, and quiet interval labels.
- The bottom native Liquid Glass buttons float over the scrolling instrument, without a dark backing strip.
- Use **Instrument controls** for 30–240 BPM, presets, 220–1,760 Hz tick pitch, volume, swing, independent sound/haptic switches, and motion lighting.
- Tilt the phone to bend the metal and ticker seen through the glass, alongside the layered rim reflections. A faint highlight glides along the perimeter, and a subtle red/blue split catches diagonal edge detail. The glass face stays clear. Moderate tilts are amplified; distortion and color separation fade smoothly at the lens rim. The text, Stepper and glass center stay anchored. Reduce Motion disables tilt and sweeping phase markers; Reduce Transparency disables the added optical effects and hazy lighting. The dial supports VoiceOver adjustment and all content can scroll with larger text.
- Open the atom button for equations, signal assumptions, units, and hardware limits.

The app plays in the foreground and keeps the display awake while running. Leaving the active app, an audio interruption, or disconnecting the output stops playback. Tempo and sound edits apply to the existing audio graph at a render boundary. Tempo edits preserve beat position and bar progression; existing tick tails retain their original pitch and envelope. Rim/crown movement uses detent hysteresis to reject finger jitter. Haptic detents are cached and capped at 20 per second. The crown controls remain outside the animation timelines. During an edit, the gauge shows the requested BPM; telemetry, waveform, and phase follow the acknowledged audio clock, with an **APPLYING SETTINGS** indicator until it catches up.

Control touches belong to the instrument: turning the rim or either crown, pressing their step buttons, and using the main/settings stepper or sliders do not pan the surrounding page. Tempo/status labels keep a constant layout height as their values change. Drag outside these controls to scroll.

## Timing and signal

`fbeat = BPM / 60`, `T = 60 / BPM`, `φ = 2π · fractional(beats)`. At constant tempo, `beats = t / T`; live tempo edits preserve accumulated beats and replace only their rate. A beat is a quarter note. Average pulse rate is `subdivision × fbeat`. For even subdivisions, alternate pulses are delayed by `swing × T / subdivision`; quarter note boundaries remain steady. Pulse timestamps derive from beat position and integer indices, without accumulated timer intervals.

Audio uses an `AVAudioSourceNode` and the HAL presentation timestamp, with a future monotonic downbeat armed atomically after the graph starts. Its callback runs outside the main actor, reads a lock-free atomic parameter mailbox once per buffer, and does not acquire locks or allocate arrays. A shared piecewise clock preserves phase when tempo changes; atomic telemetry publishes the acknowledged clock back to the gauge and haptic scheduler. Gain changes ramp to avoid discontinuities. Core Haptics has its own clock, mapped through a bracketed calibration. Tempo edits replace future scheduled pulses without restarting either engine. If UI scheduling stalls, overdue haptics are skipped rather than replayed in a burst.

Ticks are finite 55 ms signals with a smooth 1.5 ms attack, exponential decay, and a smooth final 7 ms taper. The selected frequency is the fundamental; accent changes envelope and harmonic weights while retaining the pitch. Harmonics above Nyquist are omitted. The source mixes still live prior ticks at high swing instead of truncating their tails. Shared pulse gains are 1 / 0.72 / 0.36 for downbeat / beat / subdivision, in addition to synthesis amplitude and audio volume.

Wave plots the shared kernel, including selected volume and pulse gain. Spectrum computes a DFT of that kernel at 48 kHz with 4,096 samples and 512 displayed bins (~11.72 Hz spacing). Zero padding improves bin spacing, not physical resolving power; magnitudes normalize to the largest peak. Both accent variants are cached off the main actor and recomputed only when pitch changes. These are synthesized signal models, not microphone measurements or a full overlapping pulse-train spectrum.

Haptic intensity encodes accents. Sharpness encodes pitch as `clamp(log2(pitch / 220) / 3, 0...1)` with a small downbeat increment. An iPhone does not expose arbitrary actuator carrier frequency. Audio routing, Bluetooth, displays, and haptic hardware add latency; sample accurate scheduling does not promise zero physical output delay. Motion lighting is an artistic optical model driven by filtered gravity, not a ray-traced refractive material or mechanical escapement simulation. The centered glass lens uses the system's native clear material at a constant composite opacity. One Metal sampling layer affects only the underlying dial Canvas, with a maximum displacement of 2.5% of gauge diameter (capped at 9.5 points) and a smooth radial feather. Total red-to-blue separation is bounded to one point at a 322-point gauge, capped at 1.2 points, and concentrated in smooth diagonal edge arcs. A separate passive 0.9-point rim arc follows tilt with constant 0.085 peak opacity and transparent ends; it adds no fill over the glass face. Foreground text and controls are separate, unfiltered layers. The lens's damped radius curve is a single analytic oscillation with continuous velocity and acceleration at beat wrap, driven by preserved musical phase. It provides a spring feel without restarting a separate animation or integrating a mechanical model.

## Build

The design-system kit also includes an optional [Metro Sea Glass material study](Materials/SeaGlass/README.md), with an adjustable browser workbench, an iOS 26+ SwiftUI package and a separate iPhone lab. It adds a satin colored surface while preserving this app's existing material design. The reusable skill routes to its [experimental extension](Skills/metro-station-design-system/references/sea-glass.md).

Open `MetroStation.xcodeproj` in Xcode 27 and select the `MetroStation` scheme. The app supports iPhone portrait and landscape, excludes iPad, Catalyst, and Mac/visionOS compatibility. Recreate the project with `xcodegen generate` if editing `project.yml`. The portable timing and synthesis package remains `MetronomeCore`.

Run portable core tests:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/metro-station-core-clang \
    SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/metro-station-core-module \
    swift test --disable-sandbox --scratch-path /private/tmp/metro-station-core-build
```

See `Documentation/QA.md` for observed validation and remaining physical checks. Earlier build logs, screenshots, device inventories and scratch paths retain the name recorded when they were produced; the rename does not rewrite historical evidence. The native Liquid Glass controls follow [Apple's custom-view API](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) and [materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials). [Core Haptics clock documentation](https://developer.apple.com/documentation/corehaptics/chhapticengine/currenttime) explains its separate timing domain.

Control touch ownership uses UIKit's [gesture failure requirements](https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldberequiredtofailby:)) to make the containing scroll pan yield to a touch beginning on a control, while allowing the control's own gesture to recognize.

Tempo names are approximate: Largo below 60, Adagio 60–75, Andante 76–107, Moderato 108–119, Allegro 120–167, Presto 168–199, and Prestissimo from 200 BPM. The right crown lands at the next or previous band's starting BPM: 30, 60, 76, 108, 120, 168, 200. These practice bands follow common musical usage described by [Yamaha's tempo guide](https://yamahacreators.com/resources/what-is-tempo-in-music); terms and ranges vary by context.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
