# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `zig build` - Build the project
- `zig build run` - Run the project
- `zig build test` - Run all tests
- `zig test src/lexer/lexer_test.zig` - Run specific lexer tests
- `zig test src/memory/memory_test.zig` - Run specific memory tests

## Style Guidelines
- **Imports**: Use `@import()` for module imports
- **Formatting**: 4-space indentation
- **Naming**:
  - Functions: camelCase
  - Types/Structs: PascalCase
  - Error types: PascalCase with 'Error' suffix
  - Constants: snake_case
- **Error Handling**: Use Zig's error union types and `try`/`catch` syntax
- **Memory Management**: Always use explicit allocator and proper resource cleanup with `defer`
- **Testing**: Write unit tests for all functionality using Zig's test blocks
- **Documentation**: Document public APIs with clear descriptions of parameters and return values