#!/bin/bash
set -e

echo "🔨 Building Amelia Shell for Linux..."
flutter build linux --release

echo "✅ Build complete!"
echo "🚀 You can run the shell using:"
echo "   ./build/linux/x64/release/bundle/amelia_shell"

