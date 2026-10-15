# Export actual saved favorites

After copying the iPhone application's `Documents/Styles/styles.json` to the Mac:

```sh
bash "Lab/Tools/export-phone-styles.sh" "/path/to/styles.json" "/path/to/output"
```

The helper compiles the current Foundation recipe model and exporter with the selected Xcode toolchain. It accepts only a version-1 nonempty favorite archive, verifies that decoding preserved every saved field, then writes `SeaGlassStyles.json`, `SeaGlassSavedStyles.swift` and `PhoneStyleProvenance.json`. Names, notes and identities stay intact; generated source uses safe string literals. The provenance record identifies the supplied archive and favorite identities. The caller should separately establish its device origin and record a hash if needed.

Empty favorites produce a clear error and no export directory. Unsupported versions, repeated identities or recipes requiring normalization also fail before writing. Existing QA fixtures are not user preferences and should not be passed to this helper.
