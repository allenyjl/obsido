#!/bin/bash
# Unit tests only.
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
