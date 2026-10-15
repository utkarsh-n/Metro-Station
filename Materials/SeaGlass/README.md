# Metro Sea Glass

Experimental material study 0.1 · October 13, 2026

Sea glass adds a satin, colored, gently worn surface to Metro Station. A soft face scatters the backdrop; a deeper tinted rim gives the object mass; fine stationary grain makes it feel dry and tactile. Precise foreground ink stays anchored above the material.

- [Interactive material workbench](Study/index.html): adjust frost, visual depth, light, tint, backdrop and accessibility comparisons in a browser.
- [Native SwiftUI package](Native/README.md): reusable `MetroSeaGlass` surfaces and native button styling for iOS 26+.
- [iPhone laboratory](Lab/project.yml): a separate demonstration app using the package. Generate with `xcodegen generate` from `Lab`, then open `SeaGlassLab.xcodeproj` and run the `SeaGlassLab` scheme.
- **Style workbench** in the iPhone lab: generate four variations, apply a candidate, save it with a name and preference notes, then export the saved collection as JSON and reusable Swift. Saved styles persist on the phone.
- [Material rationale and sources](Documentation/MaterialStudy.md).
- [Validation record](QA/Validation.md).

This is an optional experimental surface in the design system. The reusable skill now routes to its Sea Glass extension and includes the portable package. The existing Metro Station app and edition 1.0 foundations keep their established materials. Use this study to choose a recipe before adopting it in a product.

## Its place in Metro

| Material | Role |
| --- | --- |
| Quiet content panel | Long text, graphs and supporting explanation |
| Opaque metal | Instruments, reference geometry and mechanical detail |
| Native Liquid Glass | System-native floating controls and a clear optical lens |
| **Sea glass** | Selected tactile controls, capsules and small translucent windows with a quieter satin face |

Start with Tide at frost **0.64**, visual depth **0.55**, grain **0.45**, and an upper-left light. These are artistic controls, not measured optical properties. Tint is a material choice; preserve the host app's meanings for cyan, amber and violet signals.

The browser and native studies share a visual recipe and parameter names. Their compositors differ, so they are not pixel-identical. Native SwiftUI rendering is the adoption reference for iPhone apps.

## Adoption contracts

1. Keep values, units, foreground labels and actual control frames outside optical effects and sensor transforms.
2. Keep material opacity steady during ordinary domain events. Let data animate inside an enclosure when the data calls for it.
3. Move only a faint rim light. Maintain a quiet face and stable grain.
4. Give press feedback through a shallow change in contact shadow and rim. Keep glass rigid and its touch region steady.
5. Honor Reduce Transparency with an opaque equivalent, Reduce Motion with a fixed light, and Increased Contrast with stronger boundaries.
6. Use a small number of glass accents per screen. Keep charts and prose on calm panels.
7. Validate the actual adopting screen, composited contrast, control edges, large text and motion on its target device.

## Reference provenance

The four supplied images are visual references, not instructions or an official specification. The first explicitly credits an original concept to **@SLKVinyl** and a material concept to **Griffin Design**. Other supplied images have no independently established authorship in this study. The “Google” and “Material 4” wording in the artwork does not establish official Google provenance. This implementation is independently named **Metro Sea Glass**.

This package approximates scattered transmission using platform material, gradients and stationary texture. It does not ray trace glass, reproduce a calibrated BSDF, or model measured thickness in millimeters.

## Save and share styles

In Sea Glass Lab, adjust tint, frosting, depth, grain, roundness, light and the Metro/Mineral appearance. Scroll to **Style workbench**, choose **Generate variants**, tap one to apply it, and choose **Save current style**. Give it a meaningful name and describe the qualities you like in the notes.

**Export saved styles** opens the native share sheet with `SeaGlassStyles.json` and `SeaGlassSavedStyles.swift`. Choose Save to Files or AirDrop, then attach either file to this chat. JSON preserves exact recipe values, canonical tint RGB, names, notes and generated source. The Swift file defines `SeaGlassSavedStyles.all`, with each recipe's tint, appearance, corner radius and `SeaGlassConfiguration` ready to reuse. **Preview Swift export** lets you inspect or copy it on the phone.

The native generator is local and deterministic for a given recipe and seed. It is not a model-generated image service. Favorite recipes live in the app's `Documents/Styles/styles.json`, also available through iOS file sharing. Accessibility preferences may override the illustrated appearance and remain authoritative.

Version0.2 build2 includes the style workbench and Home Screen icon. See [device delivery and style QA](QA/Build2/Delivery.md) for evidence and limits.
