# MBL Development Roadmap: v0.1.0 → v1.0.0

## ✅ v0.1.0 - Foundation (COMPLETE)
- [x] Variable assignments (`name = "Alice"`, `age = 25`)
- [x] Basic data types (Text, Numbers, Money, Booleans)
- [x] Program output (`program.write()`)
- [x] Proper whitespace handling
- [x] Lexer → Parser → AST → Interpreter pipeline
- [x] Build system and documentation

## 🎯 v0.2.0 - String & Math Operations
- [ ] String concatenation: `"Name: " + name` support
- [ ] Basic math operators: `+`, `-`, `*`, `/` for numbers
- [ ] Money arithmetic: `$100.00 + $50.00` calculations
- [ ] Comparison operators: `==`, `!=`, `<`, `>`, `<=`, `>=`
- [ ] Type coercion: Smart conversion between compatible types
- [ ] Enhanced error messages for type mismatches

## 🔮 v0.3.0 - Control Flow & Logic
- [ ] If statements: `if condition then ... end`
- [ ] Boolean logic operators: `and`, `or`, `not`
- [ ] Nested conditions: Complex boolean expressions
- [ ] Variable scoping: Local vs program-level variables
- [ ] Improved runtime error handling
- [ ] Block statement parsing

## ⏰ v0.4.0 - Time & Advanced Data Types
- [ ] Time literals: `@2020-05-15`, `@14:30:00` support
- [ ] Time operations: Date arithmetic, formatting
- [ ] Duration types: `3 days`, `2 hours 30 minutes`
- [ ] Time comparisons: Before/after date logic
- [ ] Record types: Structured data containers
- [ ] List/array data type

## 🔄 v0.5.0 - Loops & Iteration
- [ ] For loops: `for item in collection`
- [ ] While loops: `while condition do ... end`
- [ ] List operations: Create, access, modify lists
- [ ] Range operations: `1 to 10`, `dates from start to end`
- [ ] Loop control: `break`, `continue` statements
- [ ] Iterator protocol

## 🎭 v0.6.0 - Functions & Procedures
- [ ] Function definitions: `function calculate(x, y) ... end`
- [ ] Return values: Support for function return types
- [ ] Parameter validation: Type checking for function arguments
- [ ] Built-in functions: Math, string, date utilities
- [ ] Procedure calls: Functions without return values
- [ ] Function scoping and closures

## ⚡ v0.7.0 - Activators & Reactive Programming
- [ ] Activator syntax: `when condition becomes true do ... end`
- [ ] Event triggers: Respond to data changes
- [ ] Condition monitoring: Continuous evaluation
- [ ] Activator management: Enable/disable reactive behavior
- [ ] Business rules: Automated policy enforcement
- [ ] Prevent infinite activation loops

## 📁 v0.8.0 - I/O & External Data
- [ ] File operations: `program.read("file.txt")`, `program.write_file()`
- [ ] CSV support: Read/write business data files
- [ ] JSON integration: Parse and generate JSON data
- [ ] Network requests: Basic HTTP GET/POST operations
- [ ] Database connections: Simple query capabilities
- [ ] Configuration file support

## 🚀 v0.9.0 - Advanced Features
- [ ] Error handling: `try/catch` blocks
- [ ] Multi-line comment blocks: `### ... ###`
- [ ] Code organization: Import/export between files
- [ ] Performance optimization: Faster execution engine
- [ ] Memory management: Efficient resource cleanup
- [ ] Standard library organization

## 🏆 v1.0.0 - Production Ready
- [ ] Complete language specification: Full MBL grammar documented
- [ ] Standard library: Comprehensive built-in functions
- [ ] IDE support: Syntax highlighting, auto-completion specs
- [ ] Extensive testing: Unit tests for all features
- [ ] Performance benchmarks: Production-quality speed
- [ ] Complete documentation: User manual and tutorials
- [ ] Package manager design: MBL library ecosystem
- [ ] Debugging tools: Step-through debugging support

## 🔧 Cross-Version Improvements (Ongoing)
- [ ] Code quality: Continuous refactoring and optimization
- [ ] Error messages: Increasingly helpful error diagnostics
- [ ] Test coverage: Expanding test suite with each release
- [ ] Documentation: Updated guides and examples
- [ ] Community feedback: User-requested features and fixes

---

## 📋 Next Version Checklist Template

When starting a new version:
1. [ ] Create version branch: `git checkout -b v0.x.0`
2. [ ] Update version number in relevant files
3. [ ] Implement features from version checklist above
4. [ ] Write tests for new features
5. [ ] Update documentation
6. [ ] Test with existing sample programs
7. [ ] Create new sample programs showcasing features
8. [ ] Clean up debug output
9. [ ] Tag release: `git tag v0.x.0`
10. [ ] Update ROADMAP.md with completed items

## 🎯 Current Priority: v0.2.0

The next version should focus on making the existing test file `test_datatypes.mbl` work properly by implementing string concatenation and basic expressions.