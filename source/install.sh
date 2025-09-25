#!/bin/bash
# MBL Installation Script - Installs the MBL interpreter globally

set -e

echo "🔧 MBL Language Installer"
echo "========================="

# Check if zig is installed
if ! command -v zig &> /dev/null; then
    echo "❌ Error: Zig is not installed or not in PATH"
    echo "📋 Please install Zig from https://ziglang.org/download/"
    exit 1
fi

echo "✅ Zig found: $(zig version)"

# Build the interpreter
echo "🔨 Building MBL interpreter..."
if zig build -Doptimize=ReleaseFast; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Check if the binary was created
if [ ! -f "zig-out/bin/mbl" ]; then
    echo "❌ Error: mbl binary not found in zig-out/bin/"
    exit 1
fi

# Determine installation directory
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ]; then
    echo "🔐 Administrator privileges required for installation to $INSTALL_DIR"
    echo "🚀 Installing MBL interpreter..."
    sudo cp zig-out/bin/mbl "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/mbl"
else
    echo "🚀 Installing MBL interpreter..."
    cp zig-out/bin/mbl "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/mbl"
fi

# Verify installation
if command -v mbl &> /dev/null; then
    echo "✅ Installation successful!"
    echo "📍 MBL installed to: $INSTALL_DIR/mbl"
    echo ""
    echo "🎉 You can now run MBL programs from anywhere:"
    echo "   mbl your_program.mbl"
    echo ""
    echo "📝 Example:"
    echo "   mbl demo.mbl"
    echo "   mbl test_business_complete.mbl"
else
    echo "❌ Installation verification failed!"
    echo "💡 You may need to restart your terminal or add $INSTALL_DIR to your PATH"
    exit 1
fi