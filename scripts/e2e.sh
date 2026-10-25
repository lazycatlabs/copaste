#!/bin/zsh
# Runs the end-to-end tests (CopasteE2E scheme) and collects their screenshots:
#   e2e-output/screenshots/*.png   one per checked feature
#   e2e-output/E2E.xcresult        the full report (open in Xcode)
#
#   scripts/e2e.sh [extra xcodebuild args, e.g. -only-testing:CopasteUITests/CopasteE2ETests/test01PanelHasNewLookAndAnyDayFilter]
#
# The tests drive the real UI, so leave the Mac alone while they run (about 4 minutes): moving the mouse or
# switching apps makes drag and menu tests fail. A running Copaste is quit
# first: it shares the bundle ID and would answer the test's commands.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="$PWD/e2e-output"
rm -rf "$OUT"
mkdir -p "$OUT/screenshots"

osascript -e 'tell application id "com.lazycatlabs.copaste" to quit' 2>/dev/null || true

STATUS=0
# No automatic screen recordings: they would capture whatever else is on screen.
xcodebuild -project Copaste.xcodeproj -scheme CopasteE2E -destination 'platform=macOS' \
  -resultBundlePath "$OUT/E2E.xcresult" -collect-test-diagnostics never test "$@" || STATUS=$?

# The screenshots are attachments in the report; copy them out under the names the tests gave them.
RAW=$(mktemp -d)
trap 'rm -rf "$RAW"' EXIT
xcrun xcresulttool export attachments --path "$OUT/E2E.xcresult" --output-path "$RAW" >/dev/null
python3 - "$RAW" "$OUT/screenshots" <<'PY'
import json, shutil, sys
from pathlib import Path
raw, out = Path(sys.argv[1]), Path(sys.argv[2])
for test in json.loads((raw / "manifest.json").read_text()):
    for item in test["attachments"]:
        name = item["suggestedHumanReadableName"].split("_0_")[0]
        # Only the screenshots the tests take ("01-…"), not Xcode's own failure attachments.
        if name[:2].isdigit():
            shutil.copy(raw / item["exportedFileName"], out / f"{name}.png")
PY

echo "✓ Screenshots in $OUT/screenshots"
exit $STATUS
