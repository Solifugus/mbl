#!/bin/bash

# Modern Business Language (MBL) Installation Script
echo "🚀 Installing Modern Business Language (MBL)"
echo "============================================="

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Find Zig compiler
ZIG_BINARY=""
for zig_path in "/usr/local/zig/zig" "/usr/bin/zig" "/opt/zig/zig" "$(which zig 2>/dev/null)"; do
    if [[ -x "$zig_path" ]]; then
        ZIG_BINARY="$zig_path"
        break
    fi
done

if [[ -z "$ZIG_BINARY" ]]; then
    print_error "Zig compiler not found! Install from https://ziglang.org/"
    exit 1
fi

print_success "Zig found: $($ZIG_BINARY version)"

# Build MBL
print_info "Building MBL interpreter..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$SCRIPT_DIR"
if ! $ZIG_BINARY build-exe "$PROJECT_ROOT/src/main.zig" -O ReleaseFast --name mbl; then
    print_error "Build failed"
    exit 1
fi
print_success "MBL built successfully"

# Generate system salt for encryption
print_info "Setting up encryption..."
SYSTEM_SALT=$(head -c 32 /dev/urandom | base64)
MBL_CONF_DIR="/etc/mbl"
MBL_CONF_FILE="$MBL_CONF_DIR/mbl.conf"

# Try to create system-wide config
if sudo mkdir -p "$MBL_CONF_DIR" 2>/dev/null && sudo bash -c "echo 'system_salt=$SYSTEM_SALT' > '$MBL_CONF_FILE'" 2>/dev/null; then
    sudo chmod 644 "$MBL_CONF_FILE"
    print_success "System encryption configured: $MBL_CONF_FILE"
else
    # Fallback to user-local config
    MBL_CONF_DIR="$HOME/.config/mbl"
    MBL_CONF_FILE="$MBL_CONF_DIR/mbl.conf"
    mkdir -p "$MBL_CONF_DIR"
    echo "system_salt=$SYSTEM_SALT" > "$MBL_CONF_FILE"
    chmod 600 "$MBL_CONF_FILE"
    print_success "User encryption configured: $MBL_CONF_FILE"
fi

# Install system-wide if possible
SYSTEM_INSTALLED=false

# Try /opt/mbl first (preferred for v1.0.0)
if sudo mkdir -p /opt/mbl/bin 2>/dev/null && sudo cp mbl /opt/mbl/bin/mbl 2>/dev/null; then
    sudo chmod +x /opt/mbl/bin/mbl
    # Create symlink in /usr/local/bin
    sudo ln -sf /opt/mbl/bin/mbl /usr/local/bin/mbl 2>/dev/null
    print_success "Installed to: /opt/mbl/bin/mbl"
    SYSTEM_INSTALLED=true

    # Copy examples to /opt/mbl/share/examples
    if [[ -d "$PROJECT_ROOT/examples" ]]; then
        sudo mkdir -p /opt/mbl/share/examples
        sudo cp "$PROJECT_ROOT"/examples/*.mbl /opt/mbl/share/examples/ 2>/dev/null
        print_success "Examples installed to: /opt/mbl/share/examples/"
    fi
elif mkdir -p "/usr/local/bin" 2>/dev/null && cp mbl "/usr/local/bin/mbl" 2>/dev/null; then
    chmod +x "/usr/local/bin/mbl"
    print_success "Installed to: /usr/local/bin/mbl"
    SYSTEM_INSTALLED=true
fi

# Create sample secrets file
SECRETS_FILE="$HOME/.mbl_secrets.json"
if [[ ! -f "$SECRETS_FILE" ]]; then
    cat > "$SECRETS_FILE" << 'EOF'
{
  "version": "0.17.0",
  "secrets": [
    {
      "name": "example_database",
      "attributes": {
        "host": "localhost",
        "port": "5432",
        "username": "admin",
        "password": "secure_password_here",
        "database": "myapp_production"
      },
      "tags": ["database", "production"],
      "created": 1759166312,
      "modified": 1759166312
    }
  ]
}
EOF
    print_success "Sample secrets created: $SECRETS_FILE"
fi

# Create example app
cat > example.mbl << 'EOF'
# MBL Business Application Demo
program.write("🏢 Business Application Demo")

screen = program.cli.begin()
program.cli.clear()

program.cli.write(0, 2, "🔑 Business Data Manager", color: "blue")
program.cli.write(1, 2, "========================")

user_name = program.cli.prompt(3, 2, "Enter your name: ")
program.cli.write(4, 2, "Welcome, " + user_name + "! 👋", color: "green")

db_secret = program.secret("example_database")
if db_secret != "undefined"
    program.cli.write(6, 4, "✅ Database found: " + db_secret.attributes.host, color: "green")
else
    program.cli.write(6, 4, "⚠️ No database configuration", color: "yellow")

program.cli.prompt(8, 2, "Press Enter to exit...")
program.cli.end()
program.write("Demo completed!")
EOF

echo ""
print_info "🎯 MBL Installation Complete!"
echo "📋 Features: CLI API, Secrets, Business syntax"
echo "📖 Usage:"
if [[ "$SYSTEM_INSTALLED" == true ]]; then
    echo "   mbl example.mbl"
else
    echo "   ./mbl example.mbl"
fi
print_success "🎉 Ready to build with MBL!"
