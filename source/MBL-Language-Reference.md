# MBL Language Reference v0.9.0

**Modern Business Language (MBL)** - A programming language designed for business operations with minimal learning curve and maximum readability.

## Table of Contents

1. [Language Overview](#language-overview)
2. [Syntax Fundamentals](#syntax-fundamentals)
3. [Data Types](#data-types)
4. [Variables and Assignment](#variables-and-assignment)
5. [Expressions and Operators](#expressions-and-operators)
6. [Control Flow](#control-flow)
7. [Functions and Procedures](#functions-and-procedures)
8. [Activators and Reactive Programming](#activators-and-reactive-programming) *(Planned)*
9. [Built-in Operations](#built-in-operations)
10. [Scope and Context](#scope-and-context)
11. [Comments and Documentation](#comments-and-documentation)
12. [Standard Library](#standard-library) *(Planned)*
13. [Error Handling](#error-handling) *(Planned)*

---

## Language Overview

MBL is designed around business concepts rather than computer science abstractions. Programs read like business logic and use familiar business terminology.

### Design Principles
- **Business-First**: Data types and operations reflect real business needs
- **Readable**: Code should be understandable by business stakeholders
- **Minimal Syntax**: Fewer symbols, more natural language
- **Type-Safe**: Automatic type checking with meaningful error messages

### Hello World Example
```mbl
# Simple greeting program
name = "Alice"
program.write("Hello, " + name + "!")
```

### Business Logic Example
```mbl
# Employee evaluation with new syntax
evaluate_employee(name, performance):
    program.write("Evaluating: " + name)

    if performance > 90:
        program.write("Excellent performance!")
        bonus = 1000
    else if performance > 75:
        program.write("Good performance")
        bonus = 500
    else:
        program.write("Needs improvement")
        bonus = 0

    return bonus

# Process multiple employees
employees = ["Alice", "Bob", "Charlie"]
for emp in employees:
    bonus = evaluate_employee(emp, 85)
    program.write(emp + " bonus: $" + bonus)
```

---

## Syntax Fundamentals

### Indentation-Based Structure
MBL uses Python-style indentation with colons to define code blocks:

```mbl
if budget > 1000:
    program.write("Large budget")
    discount = 0.1
else:
    program.write("Standard budget")
    discount = 0.05
```

**Key Features:**
- **Colons (`:`)** mark the start of indented blocks
- **4-space indentation** defines scope levels
- **No explicit `end` keywords** - blocks end when indentation decreases
- **Multi-line statements** supported within each indentation level

### Case Sensitivity
MBL is case-sensitive. `Name` and `name` are different variables.

### Line Structure
- One statement per line
- No semicolons required
- Empty lines are ignored
- Indentation defines scope

---

## Data Types

### Text (String)
Text values enclosed in double quotes:
```mbl
company_name = "Acme Corporation"
empty_text = Nothing        # Empty string (replaces previous "" syntax)
multi_quote = """This is a "quoted" word"""
```

**Features:**
- UTF-8 support
- Multi-quote system for embedded quotes
- Concatenation with `+` operator
- Automatic conversion from other types

### Number
Numeric values with decimal support:
```mbl
employee_count = 150
salary = 75000.50
percentage = 0.15
negative = -100
```

**Features:**
- Integer and floating-point numbers
- Automatic precision handling
- Standard arithmetic operations
- Scientific notation *(Planned)*

### Money
Currency values with automatic formatting:
```mbl
budget = $1250000.00
price = $99.99
discount = $50
```

**Features:**
- Always displays with currency symbol and decimal places
- Arithmetic operations with numbers and other money values
- Currency support (currently USD only)
- Automatic precision to cents
- *Multiple currencies planned*

### Boolean
True/false/unknown values (ternary logic):
```mbl
is_active = true
is_complete = false
customer_verified = Unknown  # For incomplete data
```

**Operations:**
- `and`, `or`, `not` operators with ternary logic
- Comparison results are boolean or Unknown
- Automatic conversion from other types
- Nothing becomes Unknown in boolean context

### Time
Date and time literals:
```mbl
meeting_date = @2024-03-15
deadline = @2024-12-31T23:59:59
start_time = @09:30:00
```

**Formats Supported:**
- `@YYYY-MM-DD` - Date only
- `@HH:MM:SS` - Time only
- `@YYYY-MM-DDTHH:MM:SS` - Full datetime
- *Duration types like `3 days` planned*

**Features:**
- Automatic parsing and validation
- Comparison operations (`<`, `>`, `==`, etc.)
- *Arithmetic operations planned*
- ISO 8601 format support

### Record (Object)
Structured data containers:
```mbl
employee = {
    name: "John Smith",
    age: 30,
    salary: $75000,
    active: true
}
```

**Features:**
- Property access: `employee.name`
- Dynamic property assignment: `employee.department = "Sales"`
- Nested records supported
- Iteration in for loops

### List (Array)
Ordered collections of values:
```mbl
departments = ["Sales", "Marketing", "IT"]
budgets = [$10000, $15000, $8000]
mixed_data = [100, "text", true, $500]
```

**Features:**
- Index access: `departments[0]`
- Mixed type support
- Iteration in for loops
- Dynamic sizing
- *List methods like `append()`, `length()` planned*

### Nothing and Unknown
Special values for missing or indeterminate data:
```mbl
name = Nothing     # Becomes empty string ""
verified = Unknown # Indeterminate boolean state
```

**Nothing behavior:**
- Nothing → "" (empty string) when used as text
- Nothing + "text" → "text" (concatenation)
- 5 + Nothing → 5 (arithmetic: Nothing becomes 0)
- true and Nothing → Unknown (boolean: Nothing unparseable)

**Universal Type Conversion:**
- All types convert to Text (universal intermediary)
- Text converts to other types when parseable
- Unparseable conversions result in Unknown

---

## Variables and Assignment

### Variable Declaration
Variables are created by assignment:
```mbl
company_name = "TechCorp"
employee_count = 250
```

### Assignment Operators
```mbl
# Basic assignment
total = 1000

# Assignment with calculation
total = price * quantity + tax
```

*Compound assignment operators (`+=`, `-=`, etc.) planned*

### Variable Naming Rules
- Start with letter or underscore
- Can contain letters, numbers, underscores
- Case-sensitive
- Cannot be MBL keywords

**Valid:** `employee_name`, `total2`, `_private`
**Invalid:** `2total`, `employee-name`, `if`

---

## Expressions and Operators

### Arithmetic Operators
```mbl
result = 10 + 5      # Addition: 15
result = 10 - 5      # Subtraction: 5
result = 10 * 5      # Multiplication: 50
result = 10 / 5      # Division: 2

# Smart type conversion
result = 5 + "25"    # 30 (string parsed as number)
result = "25" + 5    # "255" (number converted to string)
result = 5 + Nothing # 5 (Nothing becomes 0 in numeric context)
```

**Money Arithmetic:**
```mbl
budget = $1000
quarterly = budget / 4           # $250.00
total = $500 + $300             # $800.00
remaining = budget - $200        # $800.00
```

### Comparison Operators
```mbl
age == 25           # Equal to
age != 30           # Not equal to
salary > 50000      # Greater than
budget >= 100000    # Greater than or equal
count < 10          # Less than
score <= 100        # Less than or equal
```

### Logical Operators (Ternary Logic)
```mbl
is_eligible = age >= 18 and salary > 30000
needs_review = score < 60 or absent_days > 5
is_not_ready = not is_complete

# Ternary logic with Unknown values
customer_verified = Unknown
result = true and customer_verified    # Unknown
result = false or customer_verified    # Unknown
result = not customer_verified         # Unknown
```

**Ternary Truth Tables:**
- `false and anything` → `false` (false dominates)
- `true or anything` → `true` (true dominates)
- `Unknown` with inconclusive operations → `Unknown`

### String Operations
```mbl
full_name = first_name + " " + last_name
greeting = "Hello, " + name + "!"

# Smart concatenation with Nothing
message = "Status: " + Nothing     # "Status: " (Nothing becomes empty string)
name = Nothing + "John"            # "John"
```

### Operator Precedence
1. Parentheses `()`
2. Unary operators `not`, `-`
3. Multiplication, Division `*`, `/`
4. Addition, Subtraction `+`, `-`
5. Comparisons `<`, `>`, `<=`, `>=`
6. Equality `==`, `!=`
7. Logical AND `and`
8. Logical OR `or`

---

## Control Flow

### If Statements
```mbl
if budget > 100000:
    program.write("Large budget approved")
    discount = 0.15
else:
    program.write("Standard budget")
    discount = 0.05
```

**Multi-line if blocks:**
```mbl
if score >= 90:
    program.write("Excellent performance!")
    program.write("Bonus awarded")
    bonus = salary * 0.1
    grade = "A"
```

**Nested if/else statements:**
```mbl
if temperature > 80:
    program.write("Hot weather")
    if humidity > 70:
        program.write("Very humid - stay hydrated")
        warning = "Heat warning"
    else:
        program.write("Dry heat")
else:
    program.write("Comfortable weather")
```

### While Loops
```mbl
count = 1
while count <= 10:
    program.write("Count: " + count)
    count = count + 1
```

**Multi-line while loops:**
```mbl
balance = 1000
while balance > 0:
    program.write("Balance: $" + balance)
    withdrawal = 100
    balance = balance - withdrawal
    program.write("Withdrew: $" + withdrawal)
```

### For Loops
**Iterate over lists:**
```mbl
departments = ["Sales", "IT", "HR"]
for dept in departments:
    program.write("Department: " + dept)
```

**Multi-line for loops:**
```mbl
employees = ["Alice", "Bob", "Charlie"]
for employee in employees:
    program.write("Processing: " + employee)
    program.write("Status: Active")
    program.write("Department assigned")
```

**Iterate over records:**
```mbl
employee = {name: "John", age: 30, salary: 75000}
for field in employee:
    program.write("Field: " + field)  # Iterates over keys
```

### Loop Control
```mbl
for i in [1, 2, 3, 4, 5]:
    if i == 3:
        skip        # Skip to next iteration (replaces 'continue')
    if i == 5:
        breakout    # Exit loop completely (replaces 'break')
    program.write(i)
```

**Keywords:**
- **`skip`** - Continue to next iteration (replaces old `continue` keyword)
- **`breakout`** - Exit loop completely (replaces old `break` keyword)

### Todo Statements
For incomplete code blocks during development:
```mbl
if user_authenticated:
    todo  # Placeholder for future implementation
program.write("Processing complete")
```

### Nested Control Structures
**Complex nesting example:**
```mbl
for department in ["Sales", "IT", "HR"]:
    program.write("Department: " + department)

    employees = get_employees(department)
    for employee in employees:
        if employee.active:
            program.write("Active: " + employee.name)
            if employee.performance > 90:
                program.write("High performer!")
                bonus = employee.salary * 0.15
            else:
                bonus = employee.salary * 0.05
        else:
            program.write("Inactive: " + employee.name)
```

### Goto and Labels *(Legacy)*
```mbl
start:
    program.write("At start")
    if condition:
        goto end
    program.write("Middle section")

end:
    program.write("At end")
```

*Note: Goto should be used sparingly, prefer structured control flow*

---

## Functions and Procedures

MBL distinguishes between **Functions** (with parameters) and **Procedures** (without parameters) to clarify their roles in business logic.

### Functions (With Parameters)
Functions accept parameters and typically return values:

```mbl
calculate_tax(income, rate):
    tax = income * rate
    return tax
```

**Function calls:**
```mbl
employee_tax = calculate_tax(75000, 0.25)
program.write("Tax owed: " + employee_tax)
```

**Multi-line functions:**
```mbl
process_sale(price, discount_rate):
    program.write("Processing sale...")

    if discount_rate > 0:
        program.write("Applying discount")
        final_price = price * (1 - discount_rate)
    else:
        final_price = price

    program.write("Final price: " + final_price)
    return final_price

sale_amount = process_sale($100, 0.1)  # Returns $90
```

### Procedures (Without Parameters)
Procedures perform operations without parameters:

```mbl
initialize_system():
    program.write("Starting system...")
    load_configuration()
    setup_database()
    program.write("System ready!")

# Procedure call
initialize_system()
```

**Procedures vs Functions:**
- **Functions** have parameters: `calculate_tax(income, rate):`
- **Procedures** have no parameters: `initialize_system():`
- Both can access global variables and program scope
- Both support multi-line indented blocks

### Complex Function Example
```mbl
evaluate_employee(name, performance, years):
    program.write("Evaluating: " + name)

    base_score = performance * 10
    experience_bonus = years * 2

    if performance > 90:
        program.write("Excellent performer")
        bonus_multiplier = 1.5
    else if performance > 75:
        program.write("Good performer")
        bonus_multiplier = 1.2
    else:
        program.write("Needs improvement")
        bonus_multiplier = 1.0

    total_score = (base_score + experience_bonus) * bonus_multiplier
    return total_score

# Function call
score = evaluate_employee("Alice", 95, 3)
program.write("Final score: " + score)
```

### Recursive Functions
```mbl
factorial(n):
    if n <= 1:
        return 1
    else:
        return n * factorial(n - 1)

result = factorial(5)  # Returns 120
```

### Scope and Parameters
- Function parameters create local variables
- Local variables don't affect global scope
- Functions and procedures can access global variables via `program.variable`
- Return values are copied (deep copy for complex types)
- Use `super.variable` to access parent scope in nested contexts

---

## Activators and Reactive Programming *(Planned)*

Activators provide reactive programming capabilities for business rules that execute automatically when conditions become true.

### Anytime Blocks *(Planned)*
Activators use the `anytime` keyword to create reactive conditions:

```mbl
# React when inventory gets low
anytime inventory_count < 10:
    program.write("Low inventory alert!")
    send_notification("Reorder needed")
    reorder_flag = true

# React to budget changes
anytime budget > 100000:
    program.write("Large budget - executive approval required")
    approval_required = true
```

### Activator Features *(Planned)*
- **Automatic execution**: Runs when condition becomes true
- **Infinite loop prevention**: Built-in safeguards against recursive triggers
- **Business rule focus**: Designed for business logic and alerts
- **Global scope access**: Can read and modify program-level variables

### Complex Activator Example *(Planned)*
```mbl
# Multi-condition business rule
anytime (sales_total > monthly_target) and (month_end_approaching):
    program.write("Sales target exceeded!")

    bonus_pool = sales_total * 0.05
    team_notification("Bonus earned: $" + bonus_pool)

    if sales_total > monthly_target * 1.5:
        program.write("Exceptional performance!")
        executive_report = generate_report()
```

**Note**: Activators are planned for v0.10.0 and will provide powerful reactive programming capabilities for business applications.

---

## Built-in Operations

### Program Interface
```mbl
program.write("Hello World")        # Output text
program.write(variable)             # Output variable value
program.write("Result: " + result)  # Output with concatenation
```

### Scope Access
```mbl
# Access program-level variables
program.total_budget = $500000

# Access parent scope (in nested functions/blocks)
super.parent_variable = "updated"
```

*Additional built-in functions planned:*
- `program.read("filename")` - File input
- `program.write_file("filename", content)` - File output
- Mathematical functions (`math.round()`, `math.abs()`)
- String functions (`text.length()`, `text.upper()`)
- Date functions (`time.now()`, `time.format()`)

---

## Scope and Context

### Variable Scoping
MBL uses lexical scoping with these levels:

1. **Local Scope** - Function parameters and local variables
2. **Parent Scope** - Accessed via `super` keyword
3. **Program Scope** - Global variables, accessed via `program`

### Scope Resolution Example
```mbl
company_name = "Global Corp"    # Program scope

function process_department(dept_name)
    company_name = "Local Corp"     # Local scope
    program.company_name = "Modified Global"  # Program scope
    super.company_name = "Parent Scope"       # Parent scope (if nested)

    program.write(company_name)         # Prints "Local Corp"
    program.write(program.company_name) # Prints "Modified Global"
end
```

### Scope Stack
- Each function call creates a new local scope
- Block statements (if, while, for) create nested scopes
- Variables are resolved from innermost to outermost scope
- `super` and `program` provide explicit scope access

---

## Comments and Documentation

### Single-line Comments
```mbl
# This is a comment
company = "Acme"    # End-of-line comment
```

### Documentation Comments
```mbl
# Calculate quarterly budget allocation
# Input: annual_budget (Money) - Total yearly budget
# Output: Money - Budget per quarter
function quarterly_allocation(annual_budget)
    return annual_budget / 4
end
```

*Multi-line comment blocks (`### ... ###`) planned for v0.11.0*

---

## Standard Library *(Planned)*

### Mathematical Functions *(v0.10.0)*
```mbl
result = math.round(3.7)        # 4
result = math.abs(-5)           # 5
result = math.max(10, 20, 5)    # 20
result = math.min(10, 20, 5)    # 5
```

### String Functions *(v0.10.0)*
```mbl
length = text.length("hello")       # 5
upper = text.upper("hello")         # "HELLO"
lower = text.lower("HELLO")         # "hello"
trimmed = text.trim("  hello  ")    # "hello"
```

### Date/Time Functions *(v0.10.0)*
```mbl
now = time.now()                    # Current timestamp
formatted = time.format(date, "YYYY-MM-DD")
days_diff = time.days_between(start_date, end_date)
```

### File Operations *(v0.10.0)*
```mbl
content = program.read("data.txt")
program.write_file("output.txt", content)
exists = file.exists("config.txt")
```

### Data Processing *(v0.10.0)*
```mbl
csv_data = csv.read("sales.csv")
json_data = json.parse(json_string)
json_string = json.stringify(data_object)
```

---

## Error Handling *(Planned - v0.11.0)*

### Try-Catch Blocks *(Planned)*
```mbl
try
    result = risky_operation()
    program.write("Success: " + result)
catch error
    program.write("Error occurred: " + error.message)
end
```

### Error Types *(Planned)*
- `TypeError` - Type mismatch errors
- `ValueError` - Invalid values (division by zero, etc.)
- `FileError` - File operation errors
- `NetworkError` - Network operation errors

---

## Implementation Status

### ✅ Fully Implemented (v0.9.0)
- **All data types**: Text, Number, Money, Boolean, Time, Record, List
- **Ternary logic system**: true/false/Unknown with complete truth tables
- **Universal type conversion**: All types convert through Text as intermediary
- **Nothing keyword**: Proper empty string and arithmetic handling
- **Variable assignment and scoping**: Complete lexical scoping with `program`/`super` access
- **All expressions and operators**: Arithmetic, comparison, logical with ternary support
- **Complete control flow**:
  - **Colon-based syntax** (`if:`, `while:`, `for:`)
  - **Python-style indentation** (4-space levels, no `end` keywords)
  - **Multi-line indented blocks** for all constructs
  - **Nested control structures** (unlimited depth)
  - **Loop control**: `skip` (continue) and `breakout` (break)
  - **Todo statements** for development placeholders
- **Functions and procedures**: Parameter-based distinction with colon syntax
- **Built-in operations**: `program.write()` and scope access
- **Comments and documentation**: Single-line comments with `#`

### 🚧 Partially Implemented
- **Time operations**: Basic parsing implemented, arithmetic/formatting planned
- **Money types**: USD support only, multiple currencies planned
- **Function vs Procedure parsing**: Syntax defined, full implementation in progress

### 📋 Planned Features
- **v0.10.0**:
  - **Activators**: `anytime` keyword for reactive programming
  - **Enhanced loop control**: Full `skip`/`breakout` implementation
  - **File I/O**: CSV/JSON support, network requests
- **v0.11.0**:
  - **Error handling**: try/catch blocks
  - **Multi-line comments**: `### ... ###` syntax
  - **Module system**: Import/export capabilities
- **v1.0.0**:
  - **Complete standard library**: Math, string, date functions
  - **IDE support**: Language server, syntax highlighting
  - **Debugging tools**: Step-through debugging, profiling

---

## CLI Usage

### Installation
```bash
# Build and install globally
zig build -Doptimize=ReleaseFast
sudo cp zig-out/bin/mbl /usr/local/bin/

# Or use the installer
./install.sh
```

### Running Programs
```bash
# Normal mode with debug output
mbl program.mbl

# Quiet mode (clean output only)
mbl --quiet program.mbl
mbl program.mbl --quiet

# Suppress debug output to stderr
mbl program.mbl 2>/dev/null
```

### Command Options
- `--quiet` or `-q`: Suppress debug output, show only program output
- `--help`: Show usage information *(planned)*
- `--version`: Show MBL version *(planned)*

---

## Language Grammar (Simplified BNF)

```bnf
program := statement*

statement := assignment_stmt
           | expression_stmt
           | if_stmt
           | while_stmt
           | for_stmt
           | function_def
           | procedure_def
           | activator_def
           | return_stmt
           | skip_stmt
           | breakout_stmt
           | todo_stmt
           | goto_stmt
           | label_stmt

assignment_stmt := IDENTIFIER "=" expression
                 | property_access "=" expression

expression_stmt := expression

if_stmt := "if" expression ":" NEWLINE INDENT statement_block
           ("else" ":" NEWLINE INDENT statement_block)?

while_stmt := "while" expression ":" NEWLINE INDENT statement_block

for_stmt := "for" IDENTIFIER "in" expression ":" NEWLINE INDENT statement_block

function_def := IDENTIFIER "(" parameter_list? ")" ":" NEWLINE INDENT statement_block

procedure_def := IDENTIFIER "()" ":" NEWLINE INDENT statement_block

activator_def := "anytime" expression ":" NEWLINE INDENT statement_block

statement_block := statement+ DEDENT

skip_stmt := "skip"

breakout_stmt := "breakout"

todo_stmt := "todo"

expression := logical_or_expr

logical_or_expr := logical_and_expr ("or" logical_and_expr)*

logical_and_expr := equality_expr ("and" equality_expr)*

equality_expr := comparison_expr (("==" | "!=") comparison_expr)*

comparison_expr := addition_expr (("<" | ">" | "<=" | ">=") addition_expr)*

addition_expr := multiplication_expr (("+" | "-") multiplication_expr)*

multiplication_expr := unary_expr (("*" | "/") unary_expr)*

unary_expr := ("not" | "-") unary_expr | primary_expr

primary_expr := NUMBER | MONEY | TEXT | BOOLEAN | TIME
              | IDENTIFIER | property_access | function_call
              | record_literal | list_literal
              | "(" expression ")"

property_access := primary_expr "." IDENTIFIER

function_call := IDENTIFIER "(" argument_list? ")"

record_literal := "{" (IDENTIFIER ":" expression ("," IDENTIFIER ":" expression)*)? "}"

list_literal := "[" (expression ("," expression)*)? "]"
```

---

*This reference covers MBL v0.9.0 with complete colon-based syntax and Python-style indentation. For the latest updates and planned features, see the [ROADMAP.md](ROADMAP.md) file.*