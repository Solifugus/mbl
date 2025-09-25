# MBL Language v0.1.0

**Modern Business Language (MBL)** - A programming language designed for business operations with minimal learning curve and maximum readability.

## 🚀 Quick Start

### Building
```bash
./build.sh
```

### Running MBL Programs
```bash
./mbl_run <filename.mbl>
```

### Examples
```bash
./mbl_run hello.mbl
./mbl_run demo.mbl
./mbl_run test_simple_datatypes.mbl
```

## 📝 Language Features (v0.1.0)

### ✅ Supported Features
- **Variable Assignment**: `name = "Alice"`, `age = 25`
- **Data Types**:
  - Text: `"Hello World"`
  - Numbers: `42`, `98.5`
  - Money: `$1500.75`
  - Booleans: `true`, `false`
- **Program Output**: `program.write(variable)`
- **Whitespace Handling**: Proper tokenization ignores extra spaces

### 🔄 Coming Soon
- String concatenation (`"Name: " + name`)
- Time literals (`@2020-05-15`)
- Mathematical operations
- Conditional statements
- Loops and control flow

## 📋 Sample Programs

### hello.mbl
```mbl
# Hello World Program
program.write("Hello World!")
program.write( "Hello World!")
```

### Basic Variables
```mbl
# Test different MBL data types
name = "Alice Smith"
age = 25
balance = $1500.75
is_active = true
score = 98.5

program.write(name)
program.write(age)
program.write(balance)
program.write(is_active)
program.write(score)
```

## 🏗️ Architecture

MBL v0.1.0 implements a complete compiler pipeline:
1. **Lexer** - Tokenizes MBL source code
2. **Parser** - Builds Abstract Syntax Trees
3. **Interpreter** - Executes parsed programs

## 📄 License

This is an early development release of the MBL programming language.