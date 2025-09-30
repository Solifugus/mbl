// MBL Cryptographic Module
// Provides AES-256-GCM encryption with Argon2id key derivation

const std = @import("std");
const crypto = std.crypto;

pub const SALT_SIZE = 32;
pub const KEY_SIZE = 32; // AES-256
pub const NONCE_SIZE = 12; // GCM standard
pub const TAG_SIZE = 16; // GCM authentication tag

/// Generate a cryptographically secure random salt
pub fn generateSalt(allocator: std.mem.Allocator) ![]u8 {
    const salt = try allocator.alloc(u8, SALT_SIZE);
    crypto.random.bytes(salt);
    return salt;
}

/// Derive encryption key using Argon2id
/// password = system_salt + username
/// iterations = 3, memory = 64MB
pub fn deriveKey(allocator: std.mem.Allocator, password: []const u8, salt: []const u8) ![]u8 {
    const key = try allocator.alloc(u8, KEY_SIZE);

    // Argon2id parameters
    const params = crypto.pwhash.argon2.Params{
        .t = 3, // iterations
        .m = 65536, // 64MB memory (in KiB)
        .p = 1, // parallelism
    };

    try crypto.pwhash.argon2.kdf(
        allocator,
        key,
        password,
        salt,
        params,
        .argon2id,
    );

    return key;
}

/// Encrypt data using AES-256-GCM
/// Returns: nonce (12 bytes) + ciphertext + tag (16 bytes)
pub fn encrypt(allocator: std.mem.Allocator, plaintext: []const u8, key: []const u8) ![]u8 {
    if (key.len != KEY_SIZE) return error.InvalidKeySize;

    // Generate random nonce
    var nonce: [NONCE_SIZE]u8 = undefined;
    crypto.random.bytes(&nonce);

    // Allocate buffer for nonce + ciphertext + tag
    const output = try allocator.alloc(u8, NONCE_SIZE + plaintext.len + TAG_SIZE);

    // Copy nonce to beginning of output
    @memcpy(output[0..NONCE_SIZE], &nonce);

    // Prepare ciphertext and tag buffers
    const ciphertext = output[NONCE_SIZE .. NONCE_SIZE + plaintext.len];
    const tag_ptr = output[NONCE_SIZE + plaintext.len ..];

    // Encrypt using AES-256-GCM
    const aes = crypto.aead.aes_gcm.Aes256Gcm;
    var tag: [TAG_SIZE]u8 = undefined;

    aes.encrypt(
        ciphertext,
        &tag,
        plaintext,
        "", // additional data (none)
        nonce,
        key[0..KEY_SIZE].*,
    );

    // Copy tag to output
    @memcpy(tag_ptr, &tag);

    return output;
}

/// Decrypt data using AES-256-GCM
/// Input format: nonce (12 bytes) + ciphertext + tag (16 bytes)
pub fn decrypt(allocator: std.mem.Allocator, encrypted_data: []const u8, key: []const u8) ![]u8 {
    if (key.len != KEY_SIZE) return error.InvalidKeySize;
    if (encrypted_data.len < NONCE_SIZE + TAG_SIZE) return error.InvalidCiphertext;

    // Extract components
    const nonce = encrypted_data[0..NONCE_SIZE];
    const ciphertext_len = encrypted_data.len - NONCE_SIZE - TAG_SIZE;
    const ciphertext = encrypted_data[NONCE_SIZE .. NONCE_SIZE + ciphertext_len];
    const tag = encrypted_data[NONCE_SIZE + ciphertext_len ..][0..TAG_SIZE];

    // Allocate plaintext buffer
    const plaintext = try allocator.alloc(u8, ciphertext_len);

    // Decrypt using AES-256-GCM
    const aes = crypto.aead.aes_gcm.Aes256Gcm;

    aes.decrypt(
        plaintext,
        ciphertext,
        tag.*,
        "", // additional data (none)
        nonce[0..NONCE_SIZE].*,
        key[0..KEY_SIZE].*,
    ) catch |err| {
        allocator.free(plaintext);
        return err;
    };

    return plaintext;
}

/// Convert bytes to hex string
pub fn toHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const hex_chars = "0123456789abcdef";
    const hex = try allocator.alloc(u8, bytes.len * 2);

    for (bytes, 0..) |byte, i| {
        hex[i * 2] = hex_chars[byte >> 4];
        hex[i * 2 + 1] = hex_chars[byte & 0x0F];
    }

    return hex;
}

/// Convert hex string to bytes
pub fn fromHex(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidHexString;

    const bytes = try allocator.alloc(u8, hex.len / 2);

    for (0..bytes.len) |i| {
        const high = try hexCharToNibble(hex[i * 2]);
        const low = try hexCharToNibble(hex[i * 2 + 1]);
        bytes[i] = (high << 4) | low;
    }

    return bytes;
}

fn hexCharToNibble(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHexChar,
    };
}