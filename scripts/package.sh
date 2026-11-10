#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/dist/键盘灯控.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")
ARCHIVE_NAME="KeyboardLights-v${VERSION}-macOS-arm64.zip"
"$PROJECT_DIR/scripts/build.sh"
codesign --verify --strict "$APP_DIR"
# Preserve UTF-8 names and executable permissions without extended attributes or AppleDouble data.
python3 - "$APP_DIR" "$PROJECT_DIR/dist/$ARCHIVE_NAME" <<'PY'
import pathlib, sys, zipfile
app = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(sys.argv[2], 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for entry in [app, *sorted(app.rglob('*'))]:
        relative = entry.relative_to(app.parent)
        if any(part == '.DS_Store' or part.startswith('._') for part in relative.parts):
            continue
        if entry.is_symlink():
            raise RuntimeError(f'Unexpected symlink in application: {relative}')
        archive.write(entry, relative.as_posix())
PY
(cd "$PROJECT_DIR/dist" && shasum -a 256 "$ARCHIVE_NAME" > SHA256SUMS.txt)
print "Packaged: $PROJECT_DIR/dist/$ARCHIVE_NAME"
