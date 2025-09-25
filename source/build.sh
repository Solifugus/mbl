#!/bin/bash
# MBL Build Script - Compiles the MBL interpreter

echo "🔧 Building MBL Language Interpreter..."

# Build the main interpreter
if zig build-exe mbl_run.zig; then
    echo "✅ MBL interpreter built successfully!"
    echo "📁 Executable: ./mbl_run"
    echo ""
    echo "🚀 Usage:"
    echo "  ./mbl_run <filename.mbl>"
    echo ""
    echo "📝 Example:"
    echo "  ./mbl_run hello.mbl"
    echo "  ./mbl_run demo.mbl"
else
    echo "❌ Build failed!"
    exit 1
fi