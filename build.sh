#!/bin/bash
set -e

MODE="debug"
if [ "$1" == "release" ] || [ "$1" == "--release" ]; then
  MODE="release"
fi

echo "🔨 Building Amelia Shell for Linux ($MODE)..."
flutter build linux --$MODE

echo "✅ Build complete!"
echo "🚀 Executable:"
echo "   ./build/linux/x64/$MODE/bundle/amelia_shell"
