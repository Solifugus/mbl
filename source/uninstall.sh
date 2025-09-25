#!/bin/bash
# MBL Uninstallation Script - Removes the MBL interpreter from the system

set -e

echo "🗑️  MBL Language Uninstaller"
echo "============================"

# Check if MBL is installed
INSTALL_PATH=$(which mbl 2>/dev/null || echo "")

if [ -z "$INSTALL_PATH" ]; then
    echo "ℹ️  MBL is not installed (not found in PATH)"
    exit 0
fi

echo "📍 Found MBL installed at: $INSTALL_PATH"

# Check if we can write to the directory
INSTALL_DIR=$(dirname "$INSTALL_PATH")
if [ ! -w "$INSTALL_DIR" ]; then
    echo "🔐 Administrator privileges required for uninstallation"
    echo "🗑️  Removing MBL interpreter..."
    sudo rm -f "$INSTALL_PATH"
else
    echo "🗑️  Removing MBL interpreter..."
    rm -f "$INSTALL_PATH"
fi

# Verify uninstallation
if ! command -v mbl &> /dev/null; then
    echo "✅ MBL successfully uninstalled!"
else
    echo "❌ Uninstallation may have failed - MBL still found in PATH"
    echo "💡 You may need to restart your terminal or check your PATH configuration"
    exit 1
fi