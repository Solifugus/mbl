const std = @import("std");
const lexer_mod = @import("lexer.zig");
const Lexer = lexer_mod.Lexer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get filename from command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("Usage: debug_tokens <filename>\n", .{});
        return;
    }

    // Read the file
    const filename = args[1];
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.debug.print("Error opening file '{s}': {s}\n", .{filename, @errorName(err)});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const source = try allocator.alloc(u8, file_size);
    defer allocator.free(source);
    _ = try file.readAll(source);

    std.debug.print("Source ({d} chars): {s}\n", .{source.len, source});
    std.debug.print("Characters: ", .{});
    for (source) |char| {
        if (char == '\n') {
            std.debug.print("\\n", .{});
        } else if (char == '\t') {
            std.debug.print("\\t", .{});
        } else {
            std.debug.print("{c}", .{char});
        }
    }
    std.debug.print("\n", .{});

    var lexer = Lexer.init(allocator, source);

    const tokens = try lexer.scanTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |token, i| {
        std.debug.print("Token {}: type={s}, lexeme='{s}'\n", .{i, token.type.toString(), token.lexeme});
    }

    // Also test parsing
    const parser_mod = @import("parser.zig");
    var parser = parser_mod.Parser.init(allocator, tokens.items);
    const statements = parser.parse() catch |err| {
        std.debug.print("Parse error: {s}\n", .{@errorName(err)});
        return;
    };
    defer {
        for (statements) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(statements);
    }

    std.debug.print("Parsed {} statements\n", .{statements.len});
    for (statements, 0..) |stmt, i| {
        std.debug.print("Statement {}: type={s}\n", .{i, @tagName(stmt)});
    }
}