# MBL v0.7.0 - Functions & Advanced Control Flow - TODO

## Progress Status: 🚧 **PLANNING PHASE**

## Core Requirements

### 🎯 **CRITICAL FUNCTION BEHAVIOR** (User Specification)
**Function Return Logic**:
- ✅ **With `return` statement**: Function returns the specified value
- 🔄 **Without `return` statement**: Function returns **its data scope (record)**
- 🔄 **Unassigned return values**: May be destroyed if not assigned to a variable

```mbl
# Example 1: Explicit return
calculateTotal(items):
    total = 0
    for item in items: total += item.price
    return total  # Returns the calculated total

# Example 2: Implicit return (returns function's data scope)
buildReport(data):
    title = "Sales Report"
    summary = "Total: " + calculateTotal(data.items)
    # Returns: record{title: "Sales Report", summary: "Total: 1500"}

# Example 3: Assignment vs destruction
result = buildReport(sales_data)  # Record saved to 'result'
buildReport(sales_data)           # Record may be destroyed (not assigned)
```

## Planned v0.7.0 Features

### 🚧 **TODO - Function System**
- [ ] **Function Declaration & Definition**
  - [ ] Lexer: Function declaration keywords and syntax
  - [ ] Parser: Function definition AST nodes
  - [ ] Interpreter: Function registration and storage
  - [ ] Scope: Function-local variable scoping

- [ ] **Function Calls & Parameters**
  - [ ] Parser: Function call expression parsing
  - [ ] Interpreter: Parameter passing and argument binding
  - [ ] Memory: Function parameter scoping
  - [ ] Error handling: Parameter validation

- [ ] **Return Value System** (Critical)
  - [ ] Parser: `return` statement parsing (may already exist)
  - [ ] Interpreter: Explicit return value handling
  - [ ] **CORE**: Implicit return of function data scope (record)
  - [ ] Memory: Proper cleanup of unassigned return values

- [ ] **Function Scoping & Context**
  - [ ] Local variable scoping within functions
  - [ ] Access to parent scopes (`super` keyword)
  - [ ] Function data scope record creation and management
  - [ ] Proper memory lifecycle for function contexts

### 🚧 **TODO - Advanced Control Flow**
- [ ] **Function-based Control Structures**
  - [ ] Multiple return points in functions
  - [ ] Early returns with different value types
  - [ ] Return value type consistency checking

- [ ] **Error Handling in Functions**
  - [ ] Function call error propagation
  - [ ] Parameter validation and error messages
  - [ ] Stack trace support for function calls

## Technical Implementation Strategy

### Components to Modify:
1. **Parser** (`parser.zig`):
   - Function declaration parsing
   - Function call expression parsing
   - Enhanced return statement handling

2. **Memory** (`memory.zig`):
   - Function scope record creation
   - Function parameter binding
   - Return value lifecycle management

3. **Interpreter** (`interpreter.zig`):
   - Function registration and lookup
   - Function call execution
   - **CRITICAL**: Implicit data scope return logic
   - Return value assignment vs destruction

### MBL Function Syntax (from mbl-design.md):
```mbl
# Function declaration with parameters and defaults
calculate_tax(amount, rate = 0.08):
    tax = amount * rate
    return tax

# Function with multiple operations
process_order(customer, items):
    total = 0
    for item in items:
        total += item.price
    customer.balance -= total
    return total  # Explicit return

# Function with implicit return (returns data scope record)
build_summary(data):
    title = "Report Summary"
    count = data.items.length
    # Returns: record{title: "Report Summary", count: 5}
```

**Parsing Disambiguation**:
- **Function**: `name(parameters):` (parameter list with identifiers and optional defaults)
- **Label**: `name:` (identifier followed by colon, nothing else)
- **Activator**: `name condition:` (condition with comparison/logical operators)

## Test Cases to Create:
- [ ] `function_basic_test.mbl` - Simple function declaration and calls
- [ ] `function_return_test.mbl` - Explicit vs implicit return behavior
- [ ] `function_scope_test.mbl` - Function variable scoping
- [ ] `function_params_test.mbl` - Parameter passing and binding
- [ ] `function_lifecycle_test.mbl` - Memory management and destruction

## Design Document Review Needed:
- Review `mbl-design.md` for function syntax specifications
- Understand MBL's approach to function definitions
- Clarify function call syntax and parameter passing
- Document expected behavior for implicit returns

## Status & Next Steps:
**Current Status**: Requirements gathering and planning
**Next Step**: Review MBL design document for function specifications
**Priority**: Implement core function declaration and call mechanism first

---
*MBL v0.7.0 planning initiated - Focus on robust function system with proper return behavior*