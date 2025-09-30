# Modern Business Language (MBL)

**A programming language designed for business operations with minimal learning curve and maximum readability.**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](docs/changelog)
[![License](https://img.shields.io/badge/license-see%20LICENSE-green.svg)](LICENSE)
[![Build](https://img.shields.io/badge/build-passing-brightgreen.svg)](build/)

## Overview

MBL (Modern Business Language) combines the readability of Python, the business focus of COBOL, and the performance of compiled languages. It's designed specifically for business automation, data processing, file management, and professional CLI applications.

## Features

- **📊 Business-First Design**: Data types and operations that reflect real business needs
- **📁 Complete File Operations**: Directory management, file metadata, batch operations
- **🔐 Encrypted Secrets**: AES-256-GCM encryption with Argon2id key derivation
- **🖥️ Professional CLI API**: Colors, positioning, user input for terminal applications
- **🌐 Web Services**: Built-in HTTP client/server with REST API support
- **💾 Database Integration**: ODBC support for enterprise databases
- **⚡ Real-time Communication**: MCP protocol for AI/LLM integration
- **💼 Business Data Types**: Money, Time, Records, Lists with intuitive operations

## Quick Start

### Installation

```bash
cd build
./install.sh
```

This will:
- Build the MBL compiler
- Install to `/opt/mbl/bin/mbl` (or `/usr/local/bin/mbl`)
- Set up system encryption salt in `/etc/mbl/mbl.conf`
- Create example programs

### Hello World

```mbl
# hello.mbl
program.write("Hello, Business World!")
```

Run it:
```bash
mbl hello.mbl
```

### Business Example

```mbl
# File organization automation
entries = program.dir_list("/documents")
for entry in entries:
    if entry.type = "file":
        if entry.name.ends_with(".pdf"):
            program.file_move("/documents/" + entry.name, "/documents/pdfs/" + entry.name)
            program.write("📄 Organized: " + entry.name)
```

## Documentation

- **[Language Reference](docs/language-reference.md)** - Complete language documentation
- **[Getting Started](docs/guides/)** - Tutorials and guides
- **[API Reference](docs/language-reference.md)** - Built-in functions and methods
- **[Roadmap](docs/roadmap.md)** - Development plans and features

## Project Structure

```
mbl/
├── src/              # Core source code (Zig)
├── tests/            # Test suite
│   ├── integration/  # MBL integration tests
│   ├── unit/         # Unit tests
│   └── fixtures/     # Test data
├── examples/         # Example MBL programs
├── docs/             # Documentation
│   ├── guides/       # Tutorials and guides
│   └── changelog/    # Version history
├── build/            # Build system
├── debian/           # Debian packaging
└── scripts/          # Utility scripts
```

## Building from Source

### Prerequisites

- Zig compiler (0.11.0 or later)
- Linux/Unix system (tested on Ubuntu/Debian)

### Build Steps

```bash
cd build
zig build-exe ../src/main.zig -O ReleaseFast --name mbl
```

### Run Tests

```bash
./scripts/test.sh
```

## Language Highlights

### Business Data Types

```mbl
# Money with currency
price = $99.99
total = price * 5  # $499.95

# Time operations
meeting = @2025-01-15 14:30:00
if program.date.now() > meeting:
    program.write("Meeting has passed")

# Records (structured data)
customer = {
    name: "Alice Smith",
    email: "alice@company.com",
    balance: $1500.00
}
```

### File Operations

```mbl
# Check and process files
if program.file_exists("/data/report.pdf"):
    info = program.file_info("/data/report.pdf")
    program.write("Size: " + info.size.as_text() + " bytes")

    # Backup
    backup_dir = "/backup/" + program.date.today().as_text()
    program.dir_create(backup_dir)
    program.file_copy("/data/report.pdf", backup_dir + "/report.pdf")
```

### Encrypted Secrets

```mbl
# Secure credential management
db_config = program.secret("production_database")
if db_config != "undefined":
    # Use encrypted credentials securely
    server_config = {
        type: "postgresql",
        host: db_config.attributes.host,
        port: 5432,
        database: db_config.attributes.database,
        username: db_config.attributes.username,
        password: db_config.attributes.password
    }
    program.odbc.server("production", server_config)
```

### Professional CLI Applications

```mbl
# Interactive terminal interface
screen = program.cli.begin()
program.cli.clear()

program.cli.write(0, 2, "🏢 Business Dashboard", color: "blue")
program.cli.write(1, 2, "====================")

status = "✅ Systems operational"
program.cli.write(3, 4, status, color: "green")

program.cli.prompt(5, 2, "Press Enter to exit...")
program.cli.end()
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./scripts/test.sh`
5. Submit a pull request

## Version History

- **v1.0.0** (2025-09-29) - Production release
- **v0.18.0** (2025-09-29) - File operations & advanced I/O
- **v0.17.0** (2025-09-28) - CLI extensions & encrypted secrets
- See [changelog](docs/changelog/) for full history

## License

MBL is released under the license specified in the [LICENSE](LICENSE) file.

## Support

- **Documentation**: [docs/](docs/)
- **Examples**: [examples/](examples/)
- **Issues**: Report bugs and request features through your version control system

## Credits

Developed with a focus on making programming accessible to business professionals while maintaining the power and performance needed for production systems.

---

**MBL v1.0.0** - Modern Business Language for Modern Business Needs