#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
    printf '%s\n' 'Usage: export-phone-styles.sh INPUT_STYLES_JSON OUTPUT_DIRECTORY' \
        'Exports saved favorites into reusable JSON and Swift with a provenance record.'
    exit 0
fi
if [[ "$#" -ne 2 ]]; then
    printf '%s\n' 'Usage: export-phone-styles.sh INPUT_STYLES_JSON OUTPUT_DIRECTORY' >&2
    exit 1
fi

tool_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lab_directory="$(cd "$tool_directory/.." && pwd)"
build_directory="$(mktemp -d "${TMPDIR:-/tmp}/SeaGlassFavoriteExport.XXXXXX")"
trap 'rm -rf "$build_directory"' EXIT
swift_compiler="$(xcrun --find swiftc)"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
host_arch="$(uname -m)"

"$swift_compiler" -swift-version 6 -target "$host_arch-apple-macos14.0" \
    -sdk "$sdk_path" -module-cache-path "$build_directory/ModuleCache" \
    -o "$build_directory/export-phone-styles" \
    "$lab_directory/App/Styles/SeaGlassStyle.swift" \
    "$lab_directory/App/Styles/SeaGlassStyleExporter.swift" \
    "$tool_directory/ExportPhoneStyles.swift"
"$build_directory/export-phone-styles" "$1" "$2"
