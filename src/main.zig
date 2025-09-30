const std = @import("std");
const memory = @import("memory.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: {s} <mbl_file>", .{args[0]});
        return;
    }

    const filename = args[1];

    // Read the MBL source file
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.log.err("Error opening file '{s}': {}", .{ filename, err });
        return;
    };
    defer file.close();

    const source_code = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(source_code);

    // Initialize components
    var lex = lexer.Lexer.init(allocator, source_code, filename);

    // Tokenize
    const tokens_list = try lex.scanTokens();
    defer tokens_list.deinit();
    const tokens = tokens_list.items;

    // Parse
    var par = parser.Parser.init(allocator, tokens);
    const statements = try par.parse();

    // Execute
    var mem = memory.Memory.init(allocator);
    defer mem.deinit();

    var interp = interpreter.Interpreter.init(allocator, &mem);
    defer interp.deinit();

    try interp.execute(statements);
}