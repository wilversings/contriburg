#!/bin/bash
# run_tests.sh - Run Contriburg QML unit tests
#
# Usage:
#   ./tests/run_tests.sh
#
# Requirements:
#   - qmltestrunner-qt6 (part of Qt6 Quick Test)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo " Contriburg QML Unit Tests"
echo "========================================"
echo ""

if ! command -v qmltestrunner-qt6 &> /dev/null; then
    echo "ERROR: qmltestrunner-qt6 not found!"
    echo "Install Qt6's QML Test module (e.g., qt6-declarative-devel or qtbase-devel)"
    exit 1
fi

echo "Running tests..."
echo ""

if qmltestrunner-qt6 -input "$SCRIPT_DIR" -import "$SCRIPT_DIR/../contents/ui"; then
    EXIT_CODE=0
else
    EXIT_CODE=$?
fi

echo ""
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo " All tests PASSED!"
else
    echo " Some tests FAILED! (exit code: $EXIT_CODE)"
fi
echo "========================================"

exit $EXIT_CODE
