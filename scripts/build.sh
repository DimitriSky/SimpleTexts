#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodegen generate
xcodebuild -project SimpleTexts.xcodeproj -scheme SimpleTexts -configuration Release \
  -derivedDataPath build build
rm -rf "Simple Texts.app"
/usr/bin/ditto "build/Build/Products/Release/Simple Texts.app" "Simple Texts.app"
