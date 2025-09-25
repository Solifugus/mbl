const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");
const memory = @import("memory.zig");

const Lexer = lexer.Lexer;
const Parser = parser.Parser;
const Interpreter = interpreter.Interpreter;
const Memory = memory.Memory;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.info("Usage: mbl [--quiet] <filename.mbl>", .{});
        std.log.info("Example: mbl demo.mbl", .{});
        std.log.info("  --quiet  Suppress debug output", .{});
        return;
    }

    // Parse arguments
    var quiet_mode = false;
    var filename: []const u8 = "";

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--quiet") or std.mem.eql(u8, arg, "-q")) {
            quiet_mode = true;
        } else if (filename.len == 0 and !std.mem.startsWith(u8, arg, "-")) {
            filename = arg;
        }
    }

    if (filename.len == 0) {
        std.log.info("Error: No filename provided", .{});
        return;
    }

    // Read the MBL file
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.log.err("Error opening file '{s}': {}", .{filename, err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const mbl_code = try allocator.alloc(u8, file_size);
    defer allocator.free(mbl_code);

    _ = try file.readAll(mbl_code);

    if (!quiet_mode) {
        std.log.info("✓ Loaded {} bytes of MBL code", .{mbl_code.len});
        std.log.info("--- MBL Code ---", .{});
        std.log.info("{s}", .{mbl_code});
        std.log.info("--- Processing ---", .{});
    }

    // Initialize components
    var lex = Lexer.init(allocator, mbl_code);

    var mem = Memory.init(allocator);
    defer mem.deinit();

    // Tokenize
    const tokens = try lex.scanTokens();
    if (!quiet_mode) std.log.info("✓ Lexer: {} tokens", .{tokens.items.len});

    // Parse
    var main_parser = Parser.init(allocator, tokens.items);

    const statements = try main_parser.parse();
    if (!quiet_mode) std.log.info("✓ Parser: {} statements", .{statements.len});

    // Execute
    var interp = Interpreter.init(allocator, &mem);
    defer interp.deinit();

    interp.quiet_mode = quiet_mode;
    try interp.execute(statements);
    if (!quiet_mode) std.log.info("✅ Program execution completed!", .{});

    // Show program output to stdout
    const output = interp.output.items;
    if (output.len > 0) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s}", .{output});
    }

    // Clean up statements
    for (statements) |*stmt| {
        stmt.deinit(allocator);
    }
    allocator.free(statements);

    if (!quiet_mode) std.log.info("🎉 MBL Program '{s}' executed successfully!", .{filename});
}