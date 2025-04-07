# Modern Business Language (MBL)

A modern, business-focused programming language designed for readability, maintainability, and practical business operations.

## Features

- Ternary logic with Unknown type
- Built-in business types (Money, Time)
- Record-based inheritance
- Trigger-based reactivity
- Unified error handling
- Computer record for system operations

## Project Structure

```
mbl/
├── src/
│   ├── lexer/      # Tokenizer implementation
│   ├── memory/     # Memory and scope management
│   ├── parser/     # AST construction
│   └── walker/     # AST execution
├── tests/          # Test suite
└── examples/       # Example MBL programs
```

## Development

1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run tests:
   ```bash
   pytest
   ```

## License

MIT License 