# MBL v1.0.0 Project Organization Plan

## Current State Analysis

### Current Directory Structure (Messy)
```
/home/solifugus/development/mbl/source/
├── Core Source Files (*.zig)
├── Test Files (*.mbl, *.csv, *.json) - MIXED IN
├── Documentation Files (*.md) - MIXED IN
├── Build Artifacts (*.o, interpreter, mbl) - MIXED IN
├── Build System (build.zig, install.sh, uninstall.sh)
├── Subdirectories (archive/, samples/, zig-cache/, zig-out/)
└── 122 .mbl files, 40 .zig files, 8 .md files

**Problems:**
- Build artifacts mixed with source
- Test files scattered in source directory
- Documentation not organized
- No clear separation of concerns
- Binary executables in source tree
```

## Proposed v1.0.0 Structure

### Development Tree
```
/home/solifugus/development/mbl/
├── src/                        # Core source code
│   ├── main.zig               # Entry point (renamed from mbl_run.zig)
│   ├── interpreter.zig        # Core interpreter
│   ├── parser.zig             # Parser
│   ├── lexer.zig              # Lexer
│   ├── memory.zig             # Memory management
│   ├── crypto.zig             # Encryption module
│   └── odbc.zig               # Database connectivity
├── tests/                      # Test files
│   ├── unit/                  # Unit tests for Zig modules
│   ├── integration/           # MBL integration tests
│   │   ├── test_file_operations.mbl
│   │   ├── test_secrets_encryption.mbl
│   │   └── ...
│   └── fixtures/              # Test data
│       ├── *.csv
│       ├── *.json
│       └── ...
├── examples/                   # Example MBL programs
│   ├── hello_world.mbl
│   ├── business_automation.mbl
│   ├── cli_demo.mbl
│   └── file_management.mbl
├── docs/                       # Documentation
│   ├── language-reference.md  # Main language docs
│   ├── api-reference.md       # API documentation
│   ├── roadmap.md             # Development roadmap
│   ├── changelog.md           # Version history
│   └── guides/                # Tutorials and guides
│       ├── getting-started.md
│       ├── secrets-management.md
│       └── file-operations.md
├── build/                      # Build system
│   ├── build.zig              # Zig build configuration
│   ├── install.sh             # Installation script
│   └── uninstall.sh           # Uninstallation script
├── debian/                     # Debian packaging
│   ├── control                # Package metadata
│   ├── rules                  # Build rules
│   ├── install                # Installation paths
│   ├── postinst               # Post-install script
│   ├── prerm                  # Pre-remove script
│   └── changelog              # Debian changelog
├── scripts/                    # Utility scripts
│   ├── test.sh                # Run all tests
│   ├── lint.sh                # Code linting
│   └── build-deb.sh           # Build .deb package
├── LICENSE                     # License file
├── README.md                   # Project README
├── CONTRIBUTING.md             # Contribution guidelines
└── .gitignore                  # Git ignore rules
```

### Production Installation Structure
```
/opt/mbl/                       # MBL installation directory
├── bin/
│   └── mbl                    # Main executable
├── lib/
│   └── mbl/                   # Library files (if needed)
├── share/
│   ├── examples/              # Example programs
│   └── docs/                  # Documentation

/etc/mbl/                       # System configuration
├── mbl.conf                   # System salt and config
└── mbl.conf.d/                # Additional config files

/var/log/mbl/                   # Log files (if needed)

/usr/share/man/                 # Man pages
└── man1/
    └── mbl.1.gz               # MBL manual page

~/.config/mbl/                  # User configuration
├── mbl.conf                   # User-specific config
└── history                    # Command history (if REPL)

~/.mbl_secrets.json             # User secrets (encrypted)
```

## Migration Steps

### Phase 1: Clean Current Structure
1. Remove build artifacts (*.o, compiled binaries)
2. Remove zig-cache and zig-out
3. Archive old/unused files
4. Create new directory structure

### Phase 2: Organize Source Files
1. Move core *.zig files to src/
2. Rename mbl_run.zig to main.zig
3. Move test *.mbl files to tests/integration/
4. Move test data (*.csv, *.json) to tests/fixtures/
5. Move example programs to examples/

### Phase 3: Organize Documentation
1. Move all *.md files to docs/
2. Rename files to kebab-case
3. Create guides/ subdirectory
4. Split large docs into focused guides

### Phase 4: Build System Updates
1. Update build.zig for new structure
2. Update install.sh for production paths
3. Create proper uninstall.sh
4. Add build scripts to scripts/

### Phase 5: Debian Packaging
1. Create debian/ directory with control files
2. Write package metadata
3. Create installation rules
4. Write post-install script (system salt generation)
5. Write man page
6. Build .deb package

### Phase 6: Testing Infrastructure
1. Create test runner script
2. Organize unit tests
3. Create CI/CD configuration
4. Add linting tools

## File Categorization

### Keep in Root
- LICENSE
- README.md
- CONTRIBUTING.md
- .gitignore

### Move to src/
- interpreter.zig
- parser.zig
- lexer.zig
- memory.zig
- crypto.zig
- odbc.zig
- mbl_run.zig → main.zig

### Move to tests/integration/
- test_file_operations.mbl
- test_secrets_encryption.mbl
- test_secrets_write_delete.mbl
- test_simple_secret.mbl
- test_secret_delete.mbl
- All other test_*.mbl files

### Move to tests/fixtures/
- test_customers.csv
- test_config.json
- test_business_config.json
- simple_config.json
- minimal_test.csv
- minimal_csv_test.csv

### Move to examples/
- example.mbl
- Select good examples from samples/

### Move to docs/
- MBL-Language-Reference.md → language-reference.md
- ROADMAP.md → roadmap.md
- SECRETS_ENCRYPTION.md → guides/secrets-encryption.md
- MEMORY_FIXES_v0.17.0.md → guides/memory-fixes-v0.17.0.md
- V0.18.0_SUMMARY.md → changelog/v0.18.0.md
- keep_alive_summary.md → guides/keep-alive.md
- ROADMAP_old.md → archive/

### Move to build/
- build.zig
- install.sh
- uninstall.sh

### Delete (Build Artifacts)
- interpreter (binary)
- interpreter.o
- mbl (binary)
- mbl.o
- zig-cache/ (auto-generated)
- zig-out/ (auto-generated)

## Benefits of New Structure

1. **Developer Clarity**: Clear separation of source, tests, docs
2. **Professional Appearance**: Standard project layout
3. **Easier Packaging**: Standard paths for .deb creation
4. **Better Testing**: Organized test suite
5. **Documentation**: Centralized and well-organized
6. **Maintainability**: Easy to find and update files
7. **Contributor Friendly**: Standard open-source structure
8. **Production Ready**: Proper installation paths and permissions

## Implementation Priority

1. **High Priority** (Do First):
   - Clean build artifacts
   - Create new directory structure
   - Move source files
   - Update build.zig

2. **Medium Priority**:
   - Organize tests
   - Move documentation
   - Create examples directory
   - Update install script

3. **Low Priority** (Can do later):
   - Debian packaging
   - Man pages
   - CI/CD setup
   - Additional tooling