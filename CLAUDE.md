# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Modern Business Language (MBL)** - a programming language designed for business operations with minimal learning curve and maximum readability. The language prioritizes business concepts over computer science abstractions.

## Architecture

MBL consists of five core components implemented in Zig:

- **Memory** (`source/memory.zig`) - Structured data storage with type system (Record, List, Text, Number, Boolean, Money, Time, Function, Activator)
- **Lexer** (`source/lexer.zig`) - Tokenizes MBL source code with support for business-oriented literals
- **Parser** (`source/parser.zig`) - Builds Abstract Syntax Trees from tokens, handles context-sensitive parsing
- **Interpreter** (`source/interpreter.zig`) - Executes parsed code with reactive programming support
- **Server** (planned) - Runtime environment and API access

## Key Language Features

- **Business-oriented types**: Money (with currency), Time (timestamps/durations), specialized Number handling
- **Reactive programming**: Activators that execute when conditions become true
- **Scope navigation**: `super` and `program` keywords for accessing parent/global scopes
- **Context-sensitive parsing**: `=` means assignment or comparison based on context
- **Indentation-based syntax**: Python-like structure with JavaScript-like data literals
- **Built-in I/O**: `program.read`, `program.write()`, file operations, network requests

## Development Commands

### Testing
```bash
# Test individual modules (from project root)
zig test source/lexer.zig     # Lexer tests (currently no tests defined)
zig test source/parser.zig    # Parser tests (has some unused constants to fix)

# Note: memory.zig and interpreter.zig currently have compilation issues
```

### Building
```bash
# Build individual components (from source/ directory)
cd source
zig build-exe interpreter.zig  # Main interpreter (currently has syntax errors)

# Note: No build.zig file exists yet - manual compilation only
```

## Code Architecture Notes

### Memory System
- Hierarchical data storage with program as root Record
- Type conversions go through Text as base type for universal compatibility
- Supports inheritance chains through "super" record references
- Special pseudo-types: Nothing (deallocation), Unknown (error states)

### Parser Design
- Context-sensitive parsing distinguishes labels, functions, and activators by analyzing syntax patterns
- Handles MBL's unique features like multi-level string quotes and comment blocks
- AST nodes use Zig unions with proper memory management

### Interpreter Features
- Execution context with label tracking for `goto` statements
- Activator system for reactive programming (prevents infinite loops)
- Built-in program interface simulation for I/O operations

## Current Development Status

The codebase is in active development with some compilation issues:
- `source/interpreter.zig` has syntax errors (line 888)
- `source/memory.zig` has duplicate declarations
- `source/parser.zig` has unused constants
- No build system (build.zig) is currently configured

The language design is well-documented in `mbl-design.md` which serves as the comprehensive specification.