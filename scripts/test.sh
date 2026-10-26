#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodegen generate
xcodebuild -project SimpleTexts.xcodeproj -scheme SimpleTexts -derivedDataPath build test
