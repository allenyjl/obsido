#!/bin/bash
# Full verification: build, test, assemble the app bundle.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
swift test
./scripts/bundle.sh release
echo "check.sh: all green"
