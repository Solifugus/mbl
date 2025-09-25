# MBL v0.6.0 - Loops & Iteration - TODO

## Progress Status: 🚧 **IN PROGRESS**

### 🚧 **TODO**
- [ ] **For Loop Implementation** (`for item in collection:`)
  - [ ] Lexer: Add `for` and `in` keywords
  - [ ] Parser: ForStatement AST node and parsing logic
  - [ ] Interpreter: For loop execution with iteration over lists/records
  - [ ] Test: Basic for loop iteration over lists

- [ ] **While Loop Implementation** (`while condition:`)
  - [ ] Lexer: `while` keyword (may already exist)
  - [ ] Parser: WhileStatement AST node (may already exist)
  - [ ] Interpreter: While loop execution
  - [ ] Test: Basic while loop with condition

- [ ] **Range Operations** (`1 to 10`, `dates from start to end`)
  - [ ] Lexer: `to` and `from` keywords
  - [ ] Parser: Range expression parsing
  - [ ] Memory: Range type or generator
  - [ ] Interpreter: Range evaluation and iteration

- [ ] **Loop Control Statements** (`break`, `continue`)
  - [ ] Lexer: `break` and `continue` keywords
  - [ ] Parser: BreakStatement and ContinueStatement AST nodes
  - [ ] Interpreter: Loop control flow handling
  - [ ] Error handling: break/continue outside loops

- [ ] **Iterator Protocol**
  - [ ] Design iteration interface for Records and Lists
  - [ ] Implement iterator methods
  - [ ] Support for custom iteration patterns

## Technical Implementation Notes

### Components to modify:
1. **Lexer** (`lexer.zig`): Add loop-related keywords
2. **Parser** (`parser.zig`): Add loop statement parsing
3. **Memory** (`memory.zig`): Range type if needed
4. **Interpreter** (`interpreter.zig`): Loop execution logic

### Test Files to Create:
- `for_loop_test.mbl` - Basic for loop iteration
- `while_loop_test.mbl` - While loop with conditions
- `range_test.mbl` - Range operations testing
- `loop_control_test.mbl` - Break and continue statements
- `nested_loop_test.mbl` - Nested loop scenarios

## Design Document References

**For Loop Syntax** (from mbl-design.md):
```mbl
for item in items:
    total += item.price
```

**While Loop Syntax** (from mbl-design.md):
```mbl
while x < 10: x += 1
while x > 0:
    x -= 1
    program.output.append("message")
```

## Next Session Restart Point
**Current task**: Starting MBL v0.6.0 development
**Status**: TODO file created, ready to begin implementation
**Next step**: Implement for loop lexer tokens

---
*Generated during MBL v0.6.0 development session*