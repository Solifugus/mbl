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
        std.log.info("Usage: mbl_run <filename.mbl>", .{});
        std.log.info("Example: ./mbl_run demo.mbl", .{});
        return;
    }

    const filename = args[1];

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

    std.log.info("✓ Loaded {} bytes of MBL code", .{mbl_code.len});
    std.log.info("--- MBL Code ---", .{});
    std.log.info("{s}", .{mbl_code});
    std.log.info("--- Processing ---", .{});

    // Initialize components
    var lex = Lexer.init(allocator, mbl_code);

    var mem = Memory.init(allocator);
    defer mem.deinit();

    // Tokenize
    const tokens = try lex.scanTokens();
    std.log.info("✓ Lexer: {} tokens", .{tokens.items.len});

    // Parse
    var main_parser = Parser.init(allocator, tokens.items);

    const statements = try main_parser.parse();
    std.log.info("✓ Parser: {} statements", .{statements.len});

    // Execute
    var interp = Interpreter.init(allocator, &mem);
    defer interp.deinit();

    try interp.execute(statements);
    std.log.info("✅ Program execution completed!", .{});

    // Show program output
    const output = interp.output.items;
    if (output.len > 0) {
        std.log.info("--- Program Output ---", .{});
        std.log.info("{s}", .{output});
    }

    // Clean up statements
    for (statements) |*stmt| {
        stmt.deinit(allocator);
    }
    allocator.free(statements);

    std.log.info("🎉 MBL Program '{s}' executed successfully!", .{filename});
}