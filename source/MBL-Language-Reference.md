# MBL Language Reference v0.17.0

**Modern Business Language (MBL)** - A programming language designed for business operations with minimal learning curve and maximum readability.

## What's New in v0.17.0

- **🖥️ Complete CLI API**: Native terminal interface with colors, positioning, and user input
- **🔑 User-Specific Secrets**: Secure credential management with `program.secret()`
- **🎨 Professional UI Development**: Business-readable syntax for interactive applications
- **📱 Cross-Platform Terminal Support**: ANSI escape codes for universal compatibility
- **💼 Business Application Framework**: Full CLI app development capabilities

## Table of Contents

1. [Language Overview](#language-overview)
2. [Syntax Fundamentals](#syntax-fundamentals)
3. [Data Types](#data-types)
4. [Variables and Assignment](#variables-and-assignment)
5. [Expressions and Operators](#expressions-and-operators)
6. [Control Flow](#control-flow)
7. [Functions and Procedures](#functions-and-procedures)
8. [Activators and Reactive Programming](#activators-and-reactive-programming)
9. [Text Methods and Symbol System](#text-methods-and-symbol-system)
10. [File I/O and Data Processing](#file-io-and-data-processing)
11. [Database Integration and SQL Operations](#database-integration-and-sql-operations)
12. [Web Services and Network Programming](#web-services-and-network-programming)
13. [Real-time Communication with MCP](#real-time-communication-with-mcp)
14. [CLI Applications and Terminal Interface](#cli-applications-and-terminal-interface)
15. [Secrets Management](#secrets-management)
16. [Built-in Operations](#built-in-operations)
15. [Scope and Context](#scope-and-context)
16. [Comments and Documentation](#comments-and-documentation)
17. [Standard Library](#standard-library) *(Planned)*
18. [Error Handling](#error-handling)

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
Structured data containers with full multi-line support:
```mbl
# Single-line records
employee = {name: "John Smith", age: 30, salary: $75000, active: true}

# Multi-line records with indentation (v0.13.0+)
employee = {
    name: "John Smith",
    age: 30,
    salary: $75000,
    active: true,
    address: {
        street: "123 Main St",
        city: "Springfield",
        state: "IL"
    }
}
```

**Features:**
- Property access: `employee.name`
- Dynamic property assignment: `employee.department = "Sales"`
- Multi-line syntax with proper indentation support
- Nested records supported
- Mixed indentation styles supported
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

### Function Hoisting *(v0.14.0)*

**Functions can be called before they are defined** (similar to JavaScript):

```mbl
# This works - function called before definition
say("Hello from hoisted function!")

# Function defined later in the code
say(message):
    program.write("Message: " + message)

# This also works - function called after definition
say("Hello again!")
```

**Benefits of Function Hoisting:**
- **Natural Program Flow**: Write main logic at the top, helper functions below
- **Forward Declarations**: Functions can reference each other regardless of order
- **Improved Readability**: Organize code with business logic first, implementation details later

**How It Works:**
MBL uses a two-pass execution system:
1. **First Pass**: All function declarations are registered (hoisted)
2. **Second Pass**: Statements execute with all functions available

```mbl
# Business logic at the top (most important)
main_process()

# Helper functions defined below (implementation details)
main_process():
    initialize_system()
    process_data()
    generate_report()

initialize_system():
    program.write("System initialized")

process_data():
    program.write("Processing data...")

generate_report():
    program.write("Report generated")
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

## Activators and Reactive Programming

Activators provide reactive programming capabilities for business rules that execute automatically when conditions become true. They are implemented and functional in MBL v0.9.0+.

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

**Note**: Activators are implemented and functional in v0.9.0+, providing powerful reactive programming capabilities for business applications.

---

## Text Methods and Symbol System

MBL provides enhanced text manipulation capabilities and a symbol system for advanced data processing.

### Text Methods
Text values support various methods for manipulation and analysis:

```mbl
# String length and case operations
name = "Alice Johnson"
program.write("Length: " + name.len())          # Output: Length: 13
program.write("Upper: " + name.upper())         # Output: Upper: ALICE JOHNSON
program.write("Lower: " + name.lower())         # Output: Lower: alice johnson

# String searching and manipulation
email = "user@example.com"
if email.contains("@"):
    program.write("Valid email format")

# Substring operations
domain = email.substring(5)                     # Gets "example.com"
program.write("Domain: " + domain)
```

### Symbol System
The symbol system provides metadata and reflection capabilities:

```mbl
# Working with symbols and metadata
employee = {
    name: "John Doe",
    department: "Sales",
    salary: 75000
}

# Access symbol information
for key in employee.keys():
    value = employee.get(key)
    program.write(key + ": " + value)
```

**Available Text Methods:**
- `text.len()` - Returns the length of the text
- `text.upper()` - Converts to uppercase
- `text.lower()` - Converts to lowercase
- `text.contains(substring)` - Checks if text contains substring
- `text.substring(start)` - Gets substring from start position
- `text.substring(start, end)` - Gets substring from start to end

---

## File I/O and Data Processing

MBL provides comprehensive file I/O and data processing capabilities for business applications.

### File Import System
The `program.import()` function supports multiple data formats:

```mbl
# CSV file import
customers = program.import("customers.csv")
for customer in customers:
    program.write("Customer: " + customer.name + ", City: " + customer.city)

# JSON file import
config = program.import("config.json")
program.write("Database host: " + config.database.host)
program.write("Port: " + config.database.port)

# Text file import
content = program.import("data.txt")
program.write("File content: " + content)
```

### CSV Processing
CSV files are automatically parsed into structured records:

```mbl
# Example CSV: name,age,department
# John,30,Engineering
# Jane,25,Marketing

employees = program.import("employees.csv")
for emp in employees:
    program.write(emp.name + " works in " + emp.department)
    if emp.age > 25:
        program.write("Senior employee")
```

### JSON Processing
JSON files are parsed into native MBL data structures:

```mbl
# JSON file with nested structure
data = program.import("business_config.json")

# Access nested properties
program.write("Company: " + data.company.name)
program.write("Employees: " + data.company.employee_count)

# Process arrays
for location in data.locations:
    program.write("Office: " + location.city + ", " + location.country)
```

### Interactive Input/Output
Enhanced I/O capabilities for user interaction:

```mbl
# Read user input
name = program.prompt("Enter your name: ")
program.write("Hello, " + name + "!")

# Read from stdin with custom delimiter
data = program.read(" ")  # Read until space
program.write("You entered: " + data)

# Read all available stdin
all_input = program.read()
program.write("Full input: " + all_input)

# Error output
if age < 0:
    program.error("Invalid age: " + age)
```

---

## Built-in Operations

### Program Interface

#### Output Operations
```mbl
program.write("Hello World")        # Output text to stdout
program.write(variable)             # Output variable value
program.write("Result: " + result)  # Output with concatenation
program.error("Error message")      # Output to stderr
```

#### Input Operations
```mbl
# Interactive input with prompt
name = program.prompt("Enter name: ")

# Read from stdin with delimiter
word = program.read(" ")            # Read until space
line = program.read("\n")           # Read until newline
all_data = program.read()           # Read all available input
```

#### File and Data Import
```mbl
# Import various file formats
csv_data = program.import("data.csv")       # CSV files → List of Records
json_data = program.import("config.json")   # JSON files → Record/List
text_content = program.import("file.txt")   # Text files → Text
```

### Scope Access
```mbl
# Access program-level variables
program.total_budget = $500000

# Access parent scope (in nested functions/blocks)
super.parent_variable = "updated"
```

### Complete I/O Reference

**Output Functions:**
- `program.write(text)` - Write to stdout
- `program.error(text)` - Write to stderr

**Input Functions:**
- `program.prompt(message)` - Display prompt and read user input
- `program.read()` - Read all available stdin
- `program.read(delimiter)` - Read until delimiter character

**Data Import Functions:**
- `program.import(filename)` - Import file (auto-detects CSV, JSON, text)

**Text Processing Methods:**
- `text.len()` - Get text length
- `text.upper()` - Convert to uppercase
- `text.lower()` - Convert to lowercase
- `text.contains(substring)` - Check if text contains substring
- `text.substring(start)` - Get substring from position
- `text.substring(start, end)` - Get substring range

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

process_department(dept_name):
    company_name = "Local Corp"     # Local scope
    program.company_name = "Modified Global"  # Program scope
    super.company_name = "Parent Scope"       # Parent scope (if nested)

    program.write(company_name)         # Prints "Local Corp"
    program.write(program.company_name) # Prints "Modified Global"
```

### Scope Stack
- Each function call creates a new local scope
- Block statements (if, while, for) create nested scopes
- Variables are resolved from innermost to outermost scope
- `super` and `program` provide explicit scope access

---

## Comments and Documentation

### Single-line Comments

**Basic Comments:**
```mbl
# This is a comment
company = "Acme"    # End-of-line comment
```

**Hash-terminated Comments:**
```mbl
# Comment with explicit end # Regular code continues
price = 100  # Inline comment #  calculation = price * 0.1
```

### Multi-line Comments *(v0.14.0)*

**Double Hash Comments:**
```mbl
## Multi-line comment
This spans multiple lines
and can contain # single hashes
program.write("This code is commented out")
##

program.write("This code executes")
```

**Triple Hash Comments:**
```mbl
### Longer documentation comment
This is useful for detailed explanations
that might contain ## double hashes
or # single hashes within the text.

Perfect for commenting out blocks of code
that already contain other comments.
###
```

**Arbitrary Length Comments:**
```mbl
#### Four hash comment
##### Five hash comment
###### Six hash comment
```

### Nested Comment Capability

The multi-hash system allows commenting out code that contains other comments:

```mbl
### Comment out this entire block
# This single line comment # is ignored
program.write("Debug message")

## This double comment is also ignored ##
calculate_budget()
###

# This comment is active again
```

### Documentation Comments
```mbl
### Calculate quarterly budget allocation
Input: annual_budget (Money) - Total yearly budget
Output: Money - Budget per quarter

This function handles currency conversion and
ensures proper # allocation across quarters.
###
quarterly_allocation(annual_budget):
    return annual_budget / 4
```

### Best Practices

**1. Use single `#` for simple comments:**
```mbl
# Calculate tax
tax = income * 0.25
```

**2. Use `##` for temporary code blocks:**
```mbl
## Temporarily disabled feature
process_advanced_analytics()
send_notifications()
##
```

**3. Use `###` or higher for documentation:**
```mbl
### Business Logic Documentation
This section handles customer payment processing
with automatic error recovery and audit logging.
###
```

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

## Error Handling *(v0.14.0)*

MBL uses a business-friendly error handling approach that keeps programs running gracefully instead of crashing. When errors occur, they are collected in `program.errors` for review and handling.

### Error Collection System

Instead of traditional try-catch blocks, MBL collects errors in a centralized list accessible via `program.errors`:

```mbl
# Operations that might have errors
result1 = 10 / 0           # Division by zero
result2 = "abc".to_number() # Invalid conversion
result3 = file.read()      # File might not exist

# Check if any errors occurred
if program.errors == Nothing:
    program.write("All operations successful!")
else:
    program.write("Errors occurred:")
    for error in program.errors:
        program.write("- Line " + error.line + ": " + error.message)
```

### Error Handling Philosophy

**Key Principles:**
- **Self-Healing Systems**: Use activators to automatically detect and correct errors
- **Defect-Resistant Design**: Constrain operations to prevent errors before they occur
- **No Program Crashes**: Operations that fail return `Unknown` instead of stopping execution
- **Reactive Error Response**: Activators monitor `program.errors` and trigger automatic corrections
- **Business Context**: Error messages use business-friendly language
- **Robust Operation**: Systems do the right thing regardless of circumstances

### Error Record Structure

Each error in `program.errors` is a record with the following fields:

```mbl
# Example error record structure
error = {
    message: "Cannot divide by zero in budget calculation",
    line: 42,
    column: 15,
    context: "calculate_budget function",
    operation: "division",
    values: ["1000", "0"]
}
```

**Error Fields:**
- `message`: Human-readable description of the error
- `line`: Line number where error occurred (when available)
- `column`: Column number where error occurred (when available)
- `context`: Function or operation context
- `operation`: Type of operation that failed
- `values`: Input values that caused the error (for debugging)

### Working with Errors

**Checking for Errors:**
```mbl
# Simple error check
if program.errors != Nothing:
    program.error("Some operations failed")
    # Handle errors appropriately
```

**Processing All Errors:**
```mbl
if program.errors != Nothing:
    error_count = program.errors.len()
    program.write("Found " + error_count + " errors:")

    for error in program.errors:
        program.write("Error at line " + error.line + ": " + error.message)
```

**Clearing Errors:**
```mbl
# Reset error collection after handling
program.errors = Nothing
```

### Error Return Values

When operations fail, they return the `Unknown` pseudo-type instead of valid results:

```mbl
# These operations return Unknown when they fail
invalid_number = "abc".to_number()  # Returns Unknown
division_result = 10 / 0            # Returns Unknown
missing_file = program.import("nonexistent.csv")  # Returns Unknown

# Unknown values can be checked
if invalid_number == Unknown:
    program.write("Number conversion failed")
```

### Common Error Scenarios

**Type Conversion Errors:**
```mbl
text_value = "not a number"
number_result = text_value.to_number()  # Returns Unknown
# Error added to program.errors with conversion details
```

**Arithmetic Errors:**
```mbl
result = budget / 0  # Returns Unknown
# Error: "Cannot divide by zero in arithmetic operation"
```

**File Operation Errors:**
```mbl
data = program.import("missing.csv")  # Returns Unknown
# Error: "File 'missing.csv' not found or cannot be read"
```

**Database Errors:**
```mbl
result = program.odbc.run("INVALID SQL")  # Returns Unknown
# Error: "SQL syntax error: unexpected token 'INVALID'"
```

### Self-Healing with Activators

**Reactive Error Correction:**
```mbl
# Activator automatically detects and fixes division by zero
anytime program.errors != Nothing:
    for error in program.errors:
        if error.operation == "division":
            program.write("Auto-correcting division by zero...")
            # Implement fallback calculation
            if error.context == "budget_calculation":
                budget_per_employee = total_budget / 1  # Safe fallback

    program.errors = Nothing  # Clear after correction
```

**Constraint-Based Prevention:**
```mbl
# Prevent invalid operations before they occur
anytime employee_count == 0:
    program.write("Warning: No employees found, using minimum of 1")
    employee_count = 1

# Now division is always safe
budget_per_employee = total_budget / employee_count
```

**Business Rule Enforcement:**
```mbl
# Automatically maintain data consistency
anytime budget > company_limit:
    program.write("Budget exceeded limit, applying automatic adjustment")
    budget = company_limit
    audit_log = audit_log + "Budget auto-corrected on " + @now()

# System self-corrects when constraints are violated
anytime inventory_level < minimum_stock:
    program.write("Auto-reordering " + product_name)
    place_reorder(product_code, reorder_quantity)
    program.write("Emergency reorder placed automatically")
```

### Best Practices

**1. Proactive Constraint Design:**
```mbl
# Define valid ranges and automatically enforce them
anytime price < 0:
    price = 0
    program.write("Price corrected to minimum value")

anytime quantity > max_inventory:
    quantity = max_inventory
    program.write("Quantity limited to maximum capacity")
```

**2. Cascading Self-Healing:**
```mbl
# Multiple activators work together for robust systems
anytime connection_failed:
    attempt_reconnection()

anytime backup_needed and connection_active:
    create_data_backup()

anytime data_corrupted:
    restore_from_backup()
    program.write("Data automatically restored from backup")
```

**3. Defensive Programming:**
```mbl
# Systems that assume the worst and handle it gracefully
calculate_metrics():
    if customers.len() == 0:
        return { message: "No customer data available", value: 0 }

    if revenue == Unknown:
        return { message: "Revenue data unavailable", value: 0 }

    # Normal calculation only when data is valid
    return { message: "Metrics calculated successfully", value: revenue / customers.len() }
```

### Error Types and Categories

MBL automatically categorizes errors for better understanding:

**Arithmetic Errors:**
- Division by zero
- Invalid number operations
- Overflow/underflow conditions

**Type Errors:**
- Invalid type conversions
- Incompatible operation types
- Missing required fields

**I/O Errors:**
- File not found or permission denied
- Network connection failures
- Database connection or query errors

**Business Logic Errors:**
- Invalid business rule violations
- Data validation failures
- Constraint violations

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

## Database Integration and SQL Operations

MBL v0.13.0 provides comprehensive database integration through the `program.odbc` namespace, enabling business-friendly SQL operations with automatic connection management and result mapping.

### Database Server Configuration

Configure database servers using the `program.odbc.server()` function with clear, readable record syntax:

```mbl
# PostgreSQL Configuration
postgres_config = {
    type: "postgresql",
    host: "localhost",
    port: 5432,
    database: "business_db",
    username: "app_user",
    password: "secure_pass",
    charset: "utf8mb4",
    timeout: 30,
    pool_size: 10
}

# Register the server
program.odbc.server("primary", postgres_config)

# Multiple database servers
warehouse_config = {
    type: "postgresql",
    host: "warehouse.company.com",
    port: 5432,
    database: "analytics",
    username: "analytics_user",
    password: "warehouse_pass",
    ssl_mode: "require",
    pool_size: 50,
    connection_timeout: 60
}

program.odbc.server("warehouse", warehouse_config)
```

### SQL Query Execution

Execute SQL queries using the simple `program.odbc.run()` interface:

```mbl
# Basic SELECT query
users = program.odbc.run("primary", "SELECT * FROM users")

# Query with record parameters
params = {
    name: "Alice Johnson",
    min_age: 25,
    status: "active"
}

filtered_users = program.odbc.run("primary",
    "SELECT * FROM users WHERE name = {name} AND age >= {min_age} AND status = {status}",
    params)

# Query with list parameters
list_params = ["premium", 1000]
premium_users = program.odbc.run("primary",
    "SELECT * FROM users WHERE membership = {0} AND spending > {1}",
    list_params)
```

### Data Modification Operations

```mbl
# UPDATE operations
update_params = {user_id: 123, new_status: "premium"}
update_result = program.odbc.run("primary",
    "UPDATE users SET status = {new_status} WHERE id = {user_id}",
    update_params)

# INSERT operations
new_user = {
    name: "Bob Wilson",
    email: "bob@company.com",
    age: 28,
    department: "Engineering"
}

insert_result = program.odbc.run("primary",
    "INSERT INTO users (name, email, age, department) VALUES ({name}, {email}, {age}, {department})",
    new_user)

# DELETE operations
program.odbc.run("primary", "DELETE FROM temp_users WHERE created_date < '2024-01-01'")
```

### Advanced Database Operations

```mbl
# Complex business queries with multiple parameters
sales_params = {
    start_date: "2024-01-01",
    end_date: "2024-12-31",
    region: "North America",
    min_amount: 1000
}

sales_report = program.odbc.run("warehouse",
    """SELECT
         customer_name,
         SUM(order_amount) as total_sales,
         COUNT(*) as order_count
       FROM sales_transactions
       WHERE transaction_date BETWEEN {start_date} AND {end_date}
         AND region = {region}
         AND order_amount >= {min_amount}
       GROUP BY customer_name
       ORDER BY total_sales DESC""",
    sales_params)

# Cross-database operations
customer_data = program.odbc.run("primary", "SELECT * FROM customers WHERE active = true")
analytics_data = program.odbc.run("warehouse", "SELECT * FROM customer_analytics WHERE score > 0.8")
```

### Database Features

#### Automatic Connection Management
- **Connection Pooling**: Efficient connection reuse and management
- **Reconnection Handling**: Automatic reconnection on connection failures
- **Timeout Management**: Configurable connection and query timeouts

#### Business-Friendly Parameter Binding
- **Record Parameters**: `{field_name}` syntax with record values
- **List Parameters**: `{0}`, `{1}` syntax with list values
- **SQL Injection Prevention**: Automatic parameter escaping and validation
- **Type Conversion**: Automatic MBL → SQL type conversion

#### Native Result Mapping
- **List of Records**: SELECT queries return `List` of `Record` objects
- **Execution Results**: INSERT/UPDATE/DELETE return result metadata
- **Type Preservation**: Automatic SQL → MBL type conversion
- **Business Objects**: Direct integration with MBL business logic

### Database Server Types

MBL v0.13.0 supports PostgreSQL with extensible architecture for additional databases:

```mbl
# Currently supported
postgresql_server = {type: "postgresql", ...}

# Future database support architecture ready for:
# mysql_server = {type: "mysql", ...}
# sqlite_server = {type: "sqlite", ...}
# sqlserver_server = {type: "sqlserver", ...}
# oracle_server = {type: "oracle", ...}
```

---

## Web Services and Network Programming

MBL provides comprehensive web services capabilities through the `program.web` namespace, enabling both HTTP client operations and web server hosting.

### HTTP Client Operations

#### REST API Calls
```mbl
# GET request
user_data = program.get("https://api.example.com/users/123")

# POST request with data
new_user = { name: "Alice", email: "alice@example.com" }
response = program.post("https://api.example.com/users", new_user)

# PUT request (update)
updated_user = { name: "Alice Johnson", email: "alice.johnson@example.com" }
result = program.put("https://api.example.com/users/123", updated_user)

# DELETE request
program.delete("https://api.example.com/users/123")
```

### Web Server Operations

#### Server Configuration
```mbl
# HTTP server
server = program.web.listen(8080)

# HTTPS server with SSL certificate
secure_server = program.web.listen_secure(8443, "/path/to/cert.pem")

# CORS configuration
program.web.cors(["https://myapp.com", "https://admin.myapp.com"])

# Static file serving
program.web.static("/public")
```

#### Route Registration
```mbl
# Define route handlers
get_user(request):
    return { message: "User retrieved", id: request.params.id }

get_user_posts(request):
    return {
        user_id: request.params.user_id,
        post_id: request.params.post_id,
        posts: ["Post 1", "Post 2"]
    }

# Register routes with URL parameter extraction
program.web.route("GET", "/users/{id}", get_user)
program.web.route("GET", "/users/{user_id}/posts/{post_id}", get_user_posts)
program.web.route("POST", "/api/{version}/data", api_handler)
```

---

## Real-time Communication with MCP

MBL supports real-time multi-client communication through the Model Context Protocol (MCP), enabling business applications to synchronize data across multiple web clients in real-time.

### MCP Server Setup

#### Basic MCP Server
```mbl
# Start MCP server
mcp_server = program.web.mcp(8090)
program.write("MCP Server: " + mcp_server.connection_id)
```

#### Business Tool Registration
```mbl
# Define business tools for AI/client integration
get_customer_data():
    return { customer_id: 12345, name: "Acme Corp", status: "active" }

calculate_discount():
    return { discount_rate: 0.15, savings: "$2,362.50" }

# Register tools with MCP server
customer_tool = program.web.mcp_tool("get_customer",
    "Retrieve customer information and account status", get_customer_data)

discount_tool = program.web.mcp_tool("calculate_discount",
    "Calculate discounts based on customer tier", calculate_discount)
```

### Multi-Client Real-time Synchronization

#### Client Connection Management
```mbl
# Create multiple client connections
admin_client = program.web.mcp(8091)
sales_client = program.web.mcp(8092)
customer_client = program.web.mcp(8093)

program.write("Admin Dashboard: " + admin_client.connection_id)
program.write("Sales Terminal: " + sales_client.connection_id)
program.write("Customer Portal: " + customer_client.connection_id)
```

#### Channel-based Subscriptions
```mbl
# Set up role-based subscriptions
# Admin subscribes to all business data
admin_sub1 = program.web.mcp_subscribe(admin_client.connection_id, "customer_updates")
admin_sub2 = program.web.mcp_subscribe(admin_client.connection_id, "sales_data")
admin_sub3 = program.web.mcp_subscribe(admin_client.connection_id, "inventory_alerts")

# Sales team subscribes to relevant data
sales_sub1 = program.web.mcp_subscribe(sales_client.connection_id, "customer_updates")
sales_sub2 = program.web.mcp_subscribe(sales_client.connection_id, "sales_data")

# Customer portal subscribes to permitted data only
customer_sub = program.web.mcp_subscribe(customer_client.connection_id, "customer_updates")
```

#### Real-time Broadcasting
```mbl
# Broadcast business events to subscribed clients
customer_data = {
    customer_id: 12345,
    name: "Acme Corp",
    status: "premium",
    balance: "$25,750.00"
}
broadcast1 = program.web.mcp_broadcast("customer_updates", customer_data)

# Sales data (admin and sales only)
sales_data = {
    quarter: "Q4",
    revenue: "$185,000.00",
    growth: "15%",
    deals_closed: 47
}
broadcast2 = program.web.mcp_broadcast("sales_data", sales_data)

# Inventory alerts (admin only)
inventory_alert = {
    item: "Business Software License",
    quantity: 5,
    threshold: 10,
    action: "reorder"
}
broadcast3 = program.web.mcp_broadcast("inventory_alerts", inventory_alert)
```

### Activator-driven Real-time Updates

```mbl
# Activators can trigger real-time notifications
customer_status = "standard"

anytime customer_status == "premium":
    # Customer upgrade triggers cascading updates
    commission_data = { rep_id: 456, bonus: "$500.00" }
    program.web.mcp_broadcast("sales_data", commission_data)

    loyalty_update = { customer_id: 12345, tier: "gold", benefits: "free_shipping" }
    program.web.mcp_broadcast("customer_updates", loyalty_update)
```

### Role-based Filtering

MCP broadcasting automatically filters messages based on client subscriptions and roles:
- **Admin clients** receive all business data they're subscribed to
- **Sales clients** receive customer and sales data only
- **Customer clients** receive only customer-facing updates
- **Selective targeting** ensures sensitive data doesn't reach unauthorized clients

---

## CLI Applications and Terminal Interface

MBL provides a complete CLI (Command Line Interface) API for building professional terminal applications with colors, positioning, and user interaction.

### CLI Lifecycle Management

```mbl
# Initialize CLI mode
screen = program.cli.begin()

# Your CLI application code here
program.cli.clear()
program.cli.write(0, 0, "Welcome to MyApp!")

# Clean up CLI mode
program.cli.end()
```

### Screen Operations

```mbl
# Clear entire screen
program.cli.clear()

# Get terminal dimensions
size = program.cli.size()
rows = size.rows    # e.g., 24
cols = size.cols    # e.g., 80

# Refresh screen (flush output)
program.cli.refresh()
```

### Positioned Text Output

```mbl
# Write text at specific position (row, col)
program.cli.write(5, 10, "Hello World!")

# Write with color
program.cli.write(0, 0, "Header Text", color: "blue")
program.cli.write(1, 0, "Success!", color: "green")
program.cli.write(2, 0, "Warning", color: "yellow")
program.cli.write(3, 0, "Error", color: "red")
```

### Text Formatting

```mbl
# Colored text output (inline)
program.cli.color("green", "This text is green")
program.cli.color("red", "This text is red")

# Bold text formatting
program.cli.bold(true)
program.cli.write(5, 0, "This text is bold")
program.cli.bold(false)
program.cli.write(6, 0, "This text is normal")
```

### User Input

```mbl
# Simple prompt (at current cursor position)
name = program.cli.prompt("Enter your name: ")

# Positioned prompt (row, col, prompt_text)
age = program.cli.prompt(10, 5, "Enter your age: ")
city = program.cli.prompt(12, 5, "Enter your city: ")

# Wait for user acknowledgment
program.cli.prompt(20, 0, "Press Enter to continue...")
```

### Keyboard Input (Basic)

```mbl
# Get single keypress (currently mocked)
key = program.cli.getkey()    # Returns: "ENTER", "UP", "DOWN", etc.

# Get character code (currently mocked)
code = program.cli.getcode()  # Returns: 13 (for Enter), 65 (for A), etc.
```

### Complete CLI Application Example

```mbl
# Professional business CLI application
program.write("🏢 Starting Business Manager...")

# Initialize CLI
screen = program.cli.begin()
program.cli.clear()

# Professional header
program.cli.write(0, 2, "🔑 Business Data Manager v1.0", color: "blue")
program.cli.write(1, 2, "================================")

# Get user information
user_name = program.cli.prompt(3, 2, "Enter your name: ")
program.cli.write(4, 2, "Welcome, " + user_name + "! 👋", color: "green")

# Display menu
program.cli.write(6, 2, "📋 Available Options:")
program.cli.write(7, 4, "1. View reports")
program.cli.write(8, 4, "2. Manage data")
program.cli.write(9, 4, "3. Generate summaries")

# Get user choice
choice = program.cli.prompt(11, 2, "Select option (1-3): ")

# Process selection
if choice == "1"
    program.cli.write(13, 4, "📊 Loading reports...", color: "yellow")
else if choice == "2"
    program.cli.write(13, 4, "🗄️ Opening data manager...", color: "yellow")
else if choice == "3"
    program.cli.write(13, 4, "📝 Generating summaries...", color: "yellow")
else
    program.cli.write(13, 4, "❌ Invalid selection", color: "red")

# Professional exit
program.cli.prompt(15, 2, "Press Enter to exit...")
program.cli.end()

program.write("Business Manager closed successfully")
```

### CLI Color Reference

Available colors for `color:` parameter and `program.cli.color()`:
- `"red"` - Error messages, warnings
- `"green"` - Success messages, confirmations
- `"blue"` - Headers, information
- `"yellow"` - Warnings, in-progress status

---

## Secrets Management

MBL provides secure, user-specific secrets management for storing credentials, API keys, and other sensitive business data.

### Basic Secrets Access

```mbl
# Load secret from default user file (~/.mbl_secrets_{username}.json)
db_config = program.secret("database_production")

# Load secret from custom file
api_keys = program.secret("stripe_keys", "/opt/myapp/secrets.json")
```

### Working with Secrets

```mbl
# Check if secret exists
db_secret = program.secret("database_prod")

if db_secret != "undefined"
    # Access secret attributes
    host = db_secret.attributes.host
    port = db_secret.attributes.port
    username = db_secret.attributes.username
    password = db_secret.attributes.password

    # Use in application
    program.write("Connecting to: " + host + ":" + port)
else
    program.write("Database configuration not found")
```

### Secrets File Format

User-specific secrets files follow this JSON structure:

```json
{
  "version": "0.17.0",
  "secrets": [
    {
      "name": "database_production",
      "attributes": {
        "host": "db.company.com",
        "port": "5432",
        "username": "app_user",
        "password": "secure_password_123",
        "database": "production_db"
      },
      "tags": ["database", "production"],
      "created": 1759166312,
      "modified": 1759166312
    },
    {
      "name": "stripe_api",
      "attributes": {
        "public_key": "pk_live_...",
        "secret_key": "sk_live_...",
        "webhook_secret": "whsec_..."
      },
      "tags": ["api", "payment", "production"],
      "created": 1759166313,
      "modified": 1759166313
    }
  ]
}
```

### User Isolation

- **Automatic user isolation**: Each system user has separate secrets file
- **File location**: `~/.mbl_secrets_{username}.json`
- **Production ready**: Service accounts get their own isolated secrets
- **Security**: No user can access another user's secrets

### Integration with CLI Applications

```mbl
# Professional secrets-aware CLI application
screen = program.cli.begin()
program.cli.clear()

program.cli.write(0, 2, "🔐 System Configuration", color: "blue")

# Check database connection
db_secret = program.secret("main_database")
if db_secret != "undefined"
    program.cli.write(2, 4, "✅ Database: " + db_secret.attributes.host, color: "green")
else
    program.cli.write(2, 4, "❌ Database: Not configured", color: "red")

# Check API credentials
api_secret = program.secret("payment_api")
if api_secret != "undefined"
    program.cli.write(3, 4, "✅ Payment API: Configured", color: "green")
else
    program.cli.write(3, 4, "❌ Payment API: Missing", color: "red")

program.cli.prompt(5, 2, "Press Enter to continue...")
program.cli.end()
```

---

*This reference covers MBL v0.17.0 with complete CLI applications, secrets management, web services, and real-time MCP communication. For the latest updates and planned features, see the [ROADMAP.md](ROADMAP.md) file.*
