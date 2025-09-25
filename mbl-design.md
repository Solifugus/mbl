# Modern Business Language (MBL) Design Document

MBL is a programming language designed for business operations that provides minimal effort to learn, create, test, deploy, and maintain business solutions.

## Architecture

MBL consists of five core components:

- **Memory** - Structured data storage and management
- **Lexical Analyzer** - Tokenizes source code 
- **Parser** - Builds Abstract Syntax Trees from tokens
- **Interpreter** - Executes parsed code
- **Server** - Provides runtime environment and API access

## Memory System

The Memory component provides structured data storage, type conversions, retrieval, synchronization, and code execution. Data is organized as a hierarchy with the program itself as the top-level Record.

### Core Types

**Record**
- Holds any number of other types indexed by name (key-value pairs)
- Supports inheritance from a super record (cascading inheritance chain)
- Used for objects, namespaces, and the program root

**List** 
- Similar to Record but indexed numerically (arrays)
- Dynamic sizing with automatic expansion

**Text**
- UTF-8 string type and the base conversion type
- All other types must convert to/from Text to ensure universal type compatibility

**Number**
- Highest precision floating point supported by the processor
- Used for all numeric calculations and counters
- Supports standard arithmetic operations: `+`, `-`, `*`, `/`, `%` (modulo)
- Comparison operators: `=`, `!=`, `<`, `>`, `<=`, `>=`

**Boolean**
- Logical type with values `true` and `false`
- Used in conditions and logical operations
- Logical operators: `and`, `or`, `not`
- Automatically converts to Number: `true` = 1, `false` = 0

### Built-in Program Interface

**Program-Level Access**
- `program.read` - Variable containing current stdin input
- `program.write(text)` - Write text to stdout
- `program.file_read(filename)` - Read file contents as Text
- `program.file_write(filename, data)` - Write data to file
- `program.network_get(url)` - HTTP GET request, returns response
- `program.network_post(url, data)` - HTTP POST request, returns response

### Scope Navigation

**Scope Keywords**
- `super` - Access parent scope (one level up)
- `program` - Access top-level program scope from anywhere

```mbl
global_config = "production"

myfunction(param):
    local_var = "function scope"
    super.global_config = "development"    # Modify parent scope
    program.write(local_var)               # Access top-level program
```

**Money**
- Specialized type for currency values
- Properties:
  - `value`: Integer with 4 decimal places of precision (avoids floating point errors)
  - `currency`: Currency code (defaults to "USD")
  - `base`: Base denomination (defaults to "penny")
  - `conversion`: Exchange rate to USD penny for conversion calculations

**Time**
- Temporal values with dual representation
- Properties:
  - `value`: UNIX timestamp for absolute times, seconds for durations
  - Computed fields: `year`, `month`, `day`, `hour`, `minute`, `second`
  - Duration values can be directly added to timestamps

**Function**
- Executable code with local scope
- Properties:
  - Code statements stored as Abstract Syntax Tree
  - Local Record scope for variables
  - Parameter list for function calls
- Must be explicitly called to execute

**Activator**
- Reactive programming construct
- Properties:
  - Condition expression that triggers execution
  - Function to execute when condition becomes true
  - Automatically evaluated after any value change affecting the condition

### Pseudo Types

**Nothing**
- Represents absence of value or explicit deallocation
- Assigning `Nothing` to a variable deallocates its memory
- Accessing undefined variables returns `Nothing`
- Used for explicit memory management and null checks

**Unknown**
- Represents indeterminate or error states
- Assigned when operations cannot be completed (e.g., division by zero)
- Different from `Nothing` - indicates a computational problem rather than absence
- Allows programs to continue executing while marking problematic values

### Activator Execution Models

**Option 1: No Nested Execution**
Activators cannot trigger other Activators. When an Activator executes, all value changes are queued until completion, then remaining Activators fire sequentially.

**Option 2: Change Tracking + Execution Limiting**
Activators only fire when values actually change (not just assignment). Cascade chains limited to prevent infinite loops (max 10 activations per transaction).

**Option 3: Dependency Graph Prevention**
Detect circular dependencies when Activators are defined and reject circular references at creation time.

## Syntax and Lexical Rules

MBL uses Python-like indentation with JavaScript-like data structures, optimized for business readability.

### Comments

Comments do not work inside string literals and use `#` symbols:

- **Single line**: `#` to end of line, unless another `#` closes the comment
- **Multi-line**: Multiple adjacent `#` symbols create block comments closed by the same number of `#` symbols

```mbl
my_code  # comment to end of line
my_code  # comment 1 # more_code  # comment 2 # more_code
my_code  ### comment begins
more code and even ## symbols are ignored in block comment
here ### more_code
```

### String Literals

String literals do not work within comments and use matching quote patterns:

- Begin and end with the same number of consecutive quote (`"`) symbols
- Multi-line strings preserve line breaks
- No escape sequences needed due to quote matching

```mbl
name = "simple string"
multiline = "This string spans
multiple lines"
quoted = ""This string contains "quotes" inside""
```

### Whitespace and Statement Rules

- **Ignored**: Most whitespace except in comments and string literals
- **Significant**: 
  - Newlines separate statements (multiple adjacent newlines collapse to one)
  - Tabs for indentation levels (spaces not allowed for indentation)
  - Semicolons (`;`) can separate multiple statements on one line

```mbl
# Multi-line traditional style
x = 3.14
if x > 3:
    program.write("over 3")
x = 0

# Single-line with semicolons
x = 3.14; if x > 3: program.write("over 3"); x = 0

# Mixed styles as appropriate
name = "John"; age = 25; balance = $1000
if balance < $500:
    send_alert()
    request_payment()
```

### Number and Boolean Literals

```mbl
# Numbers
count = 42
price = 19.95
big_number = 1_000_000
negative = -273.15

# Booleans  
is_valid = true
is_complete = false

# String operations and built-ins
full_name = first_name + " " + last_name    # String concatenation
parts = email.split("@")                    # Split into List
clean_phone = phone.replace("-", "")        # Replace text
length = customer_name.len()                # String/List length
upper_name = name.upper()                   # Convert to uppercase
lower_email = email.lower()                 # Convert to lowercase
quoted_msg = "She said " + quote + "Hello" + quote  # Add quote character

# Built-in functions
total = sum([10, 20, 30])           # Sum of numeric List
highest = max([5, 2, 8, 1])         # Maximum value
lowest = min([5, 2, 8, 1])          # Minimum value
count = len(customer_list)          # Length of List or Text
data_type = typeof(balance)         # Returns "Money", "Text", "Number", etc.
```

- Numbers: Optional leading minus, optional decimal point, underscores for separation
- Booleans: Keywords `true` and `false`
- Arithmetic operators: `+`, `-`, `*`, `/`, `%` (modulo)
- Comparison operators: `=`, `!=`, `<`, `>`, `<=`, `>=`
- Logical operators: `and`, `or`, `not`

### Money Literals

```mbl
price = $19.95          # defaults to USD
cost = $25 PESO         # explicit currency
budget = $1_500_000     # underscores allowed
```

- Begin with `$` symbol
- Followed by number literal
- Optional currency designation

### Time Literals

```mbl
# Absolute times (stored as UNIX timestamps)
meeting = @2025-07-29 15:30:00
deadline = @2025-07-25
quarter = @2025-06
year = @2025
current = @now

# Durations (stored as seconds)
duration = @17:45:00    # 17 hours, 45 minutes
break = @2:15           # 2 hours, 15 minutes

# Time arithmetic
end_time = meeting + @2:30    # Add 2.5 hours to meeting time
```

- Absolute times: Full or partial date/datetime
- Durations: Time format without date
- Special literal: `@now` for current timestamp
- Duration arithmetic: Direct addition/subtraction of seconds

### Special Values and Memory Management

```mbl
# Nothing - explicit deallocation
large_data = load_big_file()
large_data = Nothing              # Deallocates memory immediately

# Accessing undefined variables
if customer.email = Nothing:      # Check if property doesn't exist
    request_email()

# Unknown - error states  
result = 10 / 0                   # result becomes Unknown
if result = Unknown:              # Handle computational errors
    program.write("Division by zero error")

# I/O and external access
user_input = program.read         # Read from stdin (acts like variable)
program.write("Enter your name: ")
customer_data = program.file_read("customers.csv")
program.file_write("report.txt", summary)
exchange_rate = program.network_get("https://api.rates.com/USD")

# program.read in activators
input_monitor program.read != Nothing:
    process_user_command(program.read)
    program.read = Nothing        # Clear after processing

# Labels and goto
process_order:
    validate_customer()
    if customer.status = "blocked": goto order_rejected
    
    calculate_total()
    charge_payment()
    goto order_complete

order_rejected:
    log("Order rejected for blocked customer")
    return false

order_complete:
    log("Order processed successfully") 
    return true
```

### Record and List Literals

```mbl
customer = {
    id: 21,
    name: "Joe Barnes", 
    age: 27,
    is_premium: true,
    fruits: ["apples", "oranges"],
    balance: $25.50,
    born: @1970-07-29
}

# Dynamic property assignment
customer.secret = "classified"
customer["property with spaces"] = "unusual but allowed"
```

**Code Structure**

**Labels and Control Flow**
```mbl
# Labels mark positions in code - same scope, can goto from anywhere
start_validation:
    check_customer()
    if not customer.valid: goto error_exit
    
process_payment:
    charge_account()
    if payment.failed: goto start_validation    # Can jump backwards
    goto success_exit

error_exit:
    log("Validation or payment failed")
    return false
    
success_exit:
    log("Order completed")
    return true

# Traditional control structures  
x = 0
while x < 10: x += 1

while x > 0:
    x -= 1
    program.output.append("message")
```

Labels are position markers that can be jumped to from anywhere in the same function or code block using `goto`. They do not create new scopes or loops by themselves.

**Functions**
```mbl
calculate_tax(amount, rate = 0.08):
    tax = amount * rate
    return tax

process_order(customer, items):
    total = 0
    for item in items:
        total += item.price
    customer.balance -= total
    return total
```

**Activators** 
```mbl
# Simple condition
low_balance_alert customer.balance < $100:
    send_notification("Low balance warning")

# Complex condition with grouping
order_validator (amount > $500) and (customer.status = "premium"):
    apply_discount(amount * 0.1); log_premium_order()

# Multiple statements with semicolons  
inventory_check stock.quantity < 10:
    program.write("Low stock alert"); reorder_item(); stock.status = "pending"

# Monitoring program input
user_command_handler program.read != Nothing:
    command = program.read
    super.process_command(command)
    program.read = Nothing
```

### Syntax Disambiguation

The parser distinguishes between similar constructs by analyzing content:

- **Label**: `name:` (identifier followed by colon, nothing else)
- **Function**: `name(parameters):` (parameter list with identifiers and optional defaults)  
- **Activator**: `name condition:` (condition with comparison/logical operators)
- **Assignment vs Comparison**: Context-sensitive parsing of `=` symbol

### Assignment and Comparison Context

```mbl
# Assignment context
customer.balance = $500         # Assignment
rate = 0.08                     # Assignment

# Comparison context (in conditions)
if customer.balance = $500:     # Comparison
while rate = 0.08:              # Comparison
validator amount > $100:        # Mixed operators
```

The parser determines context based on surrounding constructs (`if`, `while`, activator conditions, etc.).

## Design Philosophy

MBL prioritizes:

1. **Business Readability**: Syntax matches business concepts rather than computer science abstractions
2. **Type Safety**: Strong typing with automatic conversions through Text base type
3. **Reactive Programming**: Activators enable event-driven business logic
4. **Minimal Complexity**: Consistent patterns reduce cognitive load
5. **Error Prevention**: Language design eliminates common programming pitfalls

The result is a language where business logic can be expressed naturally while maintaining the power and safety of a formal programming environment.
