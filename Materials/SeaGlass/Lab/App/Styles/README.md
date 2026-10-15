# Named style recipes

`SeaGlassStyle` is a Foundation-only Codable snapshot. All recipe fields survive JSON roundtrip. Frost, depth and grain are clamped to 0...1; light angle to 0...360° clockwise from right in screen coordinates; corner radius to 12...64 layout points. Invalid decoded types/enums and nonfinite values receive deliberate defaults. The model contains no UIKit/SwiftUI material or sensor ownership.

`SeaGlassVariantGenerator.generate(from:seed:)` returns four deterministic candidates with distinct seeded identities. It retains appearance and accessibility preview flags, explores nearby coefficients/geometry/light, and guarantees tint alternatives. A candidate is not a favorite until the user saves it.

`SeaGlassStyleLibrary` is `@Observable @MainActor`. `saveSnapshot(of:name:notes:)` creates a fresh favorite ID and publishes it only after an atomic write succeeds. `delete(id:)` likewise persists first. The default archive is `Documents/Styles/styles.json`; `stylesURL:` supports isolated checks. Failed reads preserve the existing in-memory library and report `error`.

`SeaGlassStyleExporter.jsonData(styles:)` includes version, export metadata, artistic meanings, canonical tint RGB, complete recipes and generated Swift. `swiftSource(styles:)` produces reusable `SeaGlassSavedStyles.style1`, `style2`, etc., and `.all`. Each nested `Recipe` carries a name, notes, tint, appearance, corner radius, light angle and complete `SeaGlassConfiguration`. Strings are escaped data; user names never become code identifiers. `exportFiles(styles:directory:)` writes `SeaGlassStyles.json` and `SeaGlassSavedStyles.swift` for a share sheet.

`SeaGlassStyleChecks.swift` is excluded unless `SEAGLASS_STYLE_CHECKS` is defined. A standalone Swift 6 macOS build of the three Foundation source files plus that file passed 320 checks on October 13, 2026. Checks cover recipe roundtrip, malformed values, deterministic bounded generation, persistent favorite lifecycle/failure handling, and export values and escaping. The resulting populated and empty Swift exports also typechecked for arm64 iOS 26 against the actual `MetroSeaGlass` module. No simulator is required to run the Foundation checks.

```sh
xcrun swiftc -disable-sandbox -swift-version 6 -target arm64-apple-macos14.0 \
  -sdk /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk \
  -module-cache-path /tmp/metro-sea-glass-mac-cache -DSEAGLASS_STYLE_CHECKS \
  -o /tmp/sea-glass-style-checks-runner \
  App/Styles/SeaGlassStyle.swift App/Styles/SeaGlassStyleLibrary.swift \
  App/Styles/SeaGlassStyleExporter.swift App/Styles/SeaGlassStyleChecks.swift
/tmp/sea-glass-style-checks-runner
```

Run from the `Lab` directory. `-disable-sandbox` disables nested compiler-plugin sandboxing so the Observation macro can run inside the workspace sandbox; it does not change this app's runtime sandbox.
