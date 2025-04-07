const std = @import("std");
const Token = @import("src/lexer/token.zig").Token;
const TokenType = @import("src/lexer/token.zig").TokenType;
const MemoryManager = @import("src/memory/memory.zig").MemoryManager;
const Parser = @import("src/lexer/parser.zig").Parser;

pub fn main() !void {
    // Initialize memory manager
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();
    
    // Create some test tokens
    var tokens = try createTestTokens(allocator);
    defer allocator.free(tokens);
    
    // Create the parser
    var parser = Parser.init(tokens, &memory);
    
    std.debug.print("Parser created successfully.\n", .{});
    std.debug.print("had_error field initialized to: {any}\n", .{parser.had_error});
    std.debug.print("current token index: {d}\n", .{parser.current});
}

fn createTestTokens(allocator: std.mem.Allocator) ![]Token {
    // Create a simple program: var x = 42;
    var tokens = try allocator.alloc(Token, 5);
    
    tokens[0] = Token{
        .type = .var_,
        .lexeme = "var",
        .literal = null,
        .line = 1,
        .column = 1,
    };
    
    tokens[1] = Token{
        .type = .identifier,
        .lexeme = "x",
        .literal = null,
        .line = 1,
        .column = 5,
    };
    
    tokens[2] = Token{
        .type = .assign,
        .lexeme = "=",
        .literal = null,
        .line = 1,
        .column = 7,
    };
    
    tokens[3] = Token{
        .type = .number,
        .lexeme = "42",
        .literal = null,
        .line = 1,
        .column = 9,
    };
    
    tokens[4] = Token{
        .type = .eof,
        .lexeme = "",
        .literal = null,
        .line = 1,
        .column = 11,
    };
    
    return tokens;
}