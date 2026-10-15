# Sea glass: from weathering to interface

Research and design interpretation · October 13, 2026

## Physical observations

Beach glass is a rigid dielectric with a weathered surface. Corcoran, Packer and Biesinger's primary microscopy study identifies mechanical gouges and grooves together with chemical pits, cracks and sodium leaching. Its variation is more complex than a uniform smooth blur. Corning describes weathering frosting as a network of small surface cracks. These observations motivate low-amplitude, fixed surface texture; this implementation does not recreate the microscopic damage itself.

Microfacet models explain how surface roughness broadens reflected and transmitted light. A rough glass surface can diffuse the view behind it while retaining some reflection and transmission. For a homogeneous absorbing medium, transmittance falls exponentially with optical path length. This supports a colored-depth cue, with the exact appearance dependent on geometry and illumination.

The UI uses these relationships as design inspiration. Its frost control increases a pale scattering veil; its depth control strengthens edge color and visual elevation. These controls do not estimate a physical roughness distribution, index of refraction, measured absorption or specimen thickness.

## Reading the supplied concepts

| Reference | Transferable quality | Design decision |
| --- | --- | --- |
| 1 · message capsules | Background color diffuses through softly rounded glass | Let decorative colors read as diffuse bands through a frosted face |
| 2 · colored navigation | Body color and edge roll make the object feel substantial | Retain pigment and rounded shoulders; reduce the heavy gray shadow |
| 3 · mint composer | A visible perimeter gives thickness to a floating surface | Keep the rim subtle and stationary in shape; omit rainbow fringing |
| 4 · component sheet | Shared material works across controls and small surfaces | Build reusable primitives; keep text and boundaries more legible |

The first reference labels itself a concept and credits @SLKVinyl / Griffin Design. The “Material 4 Sea Glass” wording elsewhere is unverified concept labeling. Google's public design documentation currently identifies Material 3 and M3 Expressive. This work claims no Google affiliation or official API.

## Visual construction

The surface is built from independent layers, back to front:

1. Compact contact shadow that explains separation from the host surface.
2. Rounded translucent platform backdrop, or an opaque accessibility equivalent.
3. Low-frequency tint and a pale frost veil.
4. A deeper color band near the rounded shoulder.
5. Fine stationary micrograin clipped to the object.
6. Narrow directional rim light, held static under Reduce Motion.
7. Opaque, sharp foreground symbols and text.

Do not apply blur or refraction to the content closure. Light direction changes decorative paint, not layout. A native Button remains the action owner and its label establishes the target before decoration. The material is rigid: press response changes contact/elevation detail rather than squash, wobble or large scaling.

## Parameter meanings

| Parameter | Range | Meaning | Initial recipe |
| --- | --- | --- | --- |
| Frost | 0–1 | Artistic scattering/frost veil | 0.64 |
| Visual depth | 0–1 | Tint density at the shoulder and visual elevation | 0.55 |
| Grain | 0–1 | Microtexture strength | 0.45 |
| Light | Unit direction or angle | Narrow rim illumination direction | Upper left |
| Body color | Named tint | Material pigment, independent of domain status | Tide |

The browser study may permit wider visual exploration. SwiftUI's platform material determines its own backdrop kernel; frost is an additional surface treatment, not a controllable native blur radius. Native and browser values are conceptual counterparts, not optical calibration.

## Accessibility and interaction

The material responds to system Reduce Transparency, Reduce Motion and Increased Contrast. Foreground color depends on light/dark appearance, but hosts still need to inspect the actual backdrop and text contrast. A nominal tint token cannot establish composited contrast.

Supply complete spoken labels, values and state using the host's domain vocabulary. Pair status color with text or symbols. Retain 44-point minimum native targets and reflow at large Dynamic Type sizes. The separate lab contains controls for comparing opaque and fixed-light renderings; system accessibility preferences take precedence over those switches.

## Sources

- [Corcoran, Packer & Biesinger, 2010 · Composition and surface characteristics of beach glass](https://doi.org/10.2110/jsr.2010.077), [author-hosted full text](https://www.surfacesciencewestern.com/wp-content/uploads/jsr10_biesinger5-1.pdf): direct microscopy and composition study of beach glass.
- [Corning Museum of Glass · Frosting](https://allaboutglass.cmog.org/definition/frosting): weathering terminology.
- [Physically Based Rendering, 4th edition · Roughness Using Microfacet Theory](https://www.pbr-book.org/4ed/Reflection_Models/Roughness_Using_Microfacet_Theory): surface roughness and directional scattering.
- [Physically Based Rendering, 4th edition · Rough Dielectric BSDF](https://www.pbr-book.org/4ed/Reflection_Models/Rough_Dielectric_BSDF): rough transmissive material model.
- [Physically Based Rendering, 4th edition · Transmittance](https://www.pbr-book.org/4ed/Volume_Scattering/Transmittance): path length and absorption.
- [Google Material](https://m3.material.io/get-started): official public system naming checked for provenance.
- [Apple · ultraThinMaterial](https://developer.apple.com/documentation/swiftui/shapestyle/ultrathinmaterial): native translucent backdrop foundation.
- [Apple · accessibilityReduceTransparency](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency): opaque-background behavior under the system preference.

No source establishes this visual recipe's measured physical accuracy. It is an independently designed, physically inspired interface material.
