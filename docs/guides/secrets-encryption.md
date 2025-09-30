# MBL Secrets Encryption System

## Overview

MBL now includes a complete encryption system for securing sensitive data in secrets files. The system uses industry-standard cryptographic algorithms with proper key derivation.

## Cryptographic Design

### System Architecture

```
System Salt (32 bytes) → /etc/mbl/mbl.conf or ~/.config/mbl/mbl.conf
Per-File Salt (32 bytes) → Stored in encrypted file header
Password = System Salt + Username
Key Derivation = Argon2id(password, per-file-salt, t=3, m=64MB)
Encryption = AES-256-GCM
```

### Key Components

1. **System Salt** (generated during installation)
   - 32 random bytes generated from `/dev/urandom`
   - Stored in `/etc/mbl/mbl.conf` (system-wide) or `~/.config/mbl/mbl.conf` (user-only)
   - Base64 encoded for storage
   - Provides system-level entropy

2. **Per-File Salt** (generated per secrets file)
   - 32 random bytes generated cryptographically
   - Stored in file header as hex
   - Ensures each secrets file has unique encryption key
   - Reused when updating existing file

3. **Key Derivation** (Argon2id)
   - Password: `system_salt + username`
   - Algorithm: Argon2id (resistant to GPU/ASIC attacks)
   - Iterations: 3
   - Memory: 64MB (65536 KiB)
   - Parallelism: 1
   - Output: 32-byte encryption key

4. **Encryption** (AES-256-GCM)
   - Algorithm: AES-256 in GCM mode
   - Key size: 256 bits (32 bytes)
   - Nonce: 12 bytes (random per encryption)
   - Authentication tag: 16 bytes
   - Provides both confidentiality and authenticity

## File Format

### Encrypted Format
```
MBL_ENCRYPTED_V1:SALT_HEX:ENCRYPTED_DATA_HEX
```

Where:
- `SALT_HEX`: 64 hex characters (32 bytes)
- `ENCRYPTED_DATA_HEX`: Variable length hex string containing:
  - 12-byte nonce
  - Encrypted JSON data
  - 16-byte authentication tag

### Legacy Format

Unencrypted JSON files are still supported for backward compatibility:
```json
{
  "version": "0.17.0",
  "secrets": [...]
}
```

When an unencrypted file is updated, it will automatically be encrypted.

## API Usage

### Read Secret
```mbl
secret = program.secret("secret_name")
secret = program.secret("secret_name", "/custom/path")
```

### Write/Update Secret
```mbl
result = program.secret_write("secret_name", {
    key1: "value1",
    key2: "value2"
})
result = program.secret_write("secret_name", attributes, "/custom/path")
```

### Delete Secret
```mbl
result = program.secret_delete("secret_name")
result = program.secret_delete("secret_name", "/custom/path")
```

## Installation

The installation script (`install.sh`) automatically:
1. Generates a cryptographically secure system salt
2. Stores it in `/etc/mbl/mbl.conf` (with fallback to user config)
3. Sets appropriate permissions (644 for system, 600 for user)

## Security Properties

### What It Protects Against
- ✅ File system access without system configuration
- ✅ Secrets leakage if file is copied to another system
- ✅ Secrets leakage if file is accessed by different user
- ✅ Tampering (authenticated encryption)
- ✅ Dictionary attacks (Argon2id with memory-hard parameters)
- ✅ GPU/ASIC brute force (Argon2id)

### What It Does NOT Protect Against
- ❌ Root/admin access (root can read config and files)
- ❌ Memory dumps while secrets are in use
- ❌ Compromised user account (legitimate user can decrypt)
- ❌ Keyloggers or malware running as the user

## Implementation Files

- `crypto.zig` - Core cryptographic operations
- `interpreter.zig` - Integration with secrets system
  - `loadSystemSalt()` - Load system salt from config
  - `deriveEncryptionKey()` - Key derivation with Argon2id
  - `loadUserSecret()` - Decrypt and load secrets
  - `writeUserSecret()` - Encrypt and save secrets
  - `deleteUserSecret()` - Remove secret and re-encrypt
- `install.sh` - System salt generation during installation

## Default Locations

- **System config**: `/etc/mbl/mbl.conf`
- **User config**: `~/.config/mbl/mbl.conf`
- **Secrets file**: `~/.mbl_secrets.json`

## Migration from Unencrypted

The system automatically migrates unencrypted secrets files:
1. First read: File is loaded as plain JSON
2. First write: File is encrypted with new salt
3. All subsequent operations use encryption

No manual migration is required.

## Testing

Run the test script to verify encryption:
```bash
./mbl test_secrets_encryption.mbl
```

To verify encryption at the file level:
```bash
# Should show encrypted format, not readable JSON
cat ~/.mbl_secrets.json
```

## Performance

- Key derivation: ~50-200ms (depending on hardware)
- Encryption: <1ms for typical secrets file
- Decryption: <1ms for typical secrets file

The key derivation is intentionally slow to resist brute force attacks.

## Version History

- **v1.0** (2025-09-29): Initial implementation
  - AES-256-GCM encryption
  - Argon2id key derivation
  - System + per-file salts
  - Backward compatible with unencrypted files