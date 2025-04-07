#!/bin/bash
# Build script for MBL REPL, ignoring warnings

# Ensure zig-out/bin directory exists
mkdir -p zig-out/bin

# Build the REPL with the most permissive settings
zig build-exe src/repl.zig \
    -femit-bin=zig-out/bin/mbl-repl \
    -OReleaseSafe

# Check the result
if [ $? -eq 0 ]; then
    echo "REPL built successfully at zig-out/bin/mbl-repl"
    echo "Run it with: ./zig-out/bin/mbl-repl"
else
    echo "REPL build failed."
fi