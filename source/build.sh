#!/bin/bash
# MBL Build Script - Compiles the MBL interpreter

echo "🔧 Building MBL Language Interpreter..."

# Build the main interpreter
if zig build-exe mbl_run.zig -femit-bin=mbl; then
    echo "✅ MBL interpreter built successfully!"
    echo "📁 Executable: ./mbl"
    echo ""
    echo "🚀 Usage:"
    echo "  ./mbl <filename.mbl>"
    echo ""
    echo "📝 Example:"
    echo "  ./mbl hello.mbl"
    echo "  ./mbl demo.mbl"
else
    echo "❌ Build failed!"
    exit 1
fi