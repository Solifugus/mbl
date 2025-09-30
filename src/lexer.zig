// lexer.zig
const std = @import("std");

pub const TokenType = enum {
    // Literals
    text,
    number,
    money,
    time,
    boolean,
    identifier,

    // Operators
    assign,         // =
    plus,           // +
    minus,          // -
    multiply,       // *
    divide,         // /
    modulo,         // %
    equal,          // = (context-dependent with assign)
    not_equal,      // !=
    less_than,      // <
    greater_than,   // >
    less_equal,     // <=
    greater_equal,  // >=

    // Logical
    and_kw,         // and
    or_kw,          // or
    not_kw,         // not

    // Delimiters
    dot,            // .
    comma,          // ,
    semicolon,      // ;
    colon,          // :
    left_paren,     // (
    right_paren,    // )
    left_brace,     // {
    right_brace,    // }
    left_bracket,   // [
    right_bracket,  // ]

    // Keywords
    if_kw,          // if
    else_kw,        // else
    while_kw,       // while
    for_kw,         // for
    in_kw,          // in
    skip_kw,        // skip (replaces continue)
    breakout_kw,    // breakout (replaces break)
    to_kw,          // to (for ranges)
    return_kw,      // return
    anytime_kw,     // anytime (for activators)
    todo_kw,        // todo (empty block placeholder)
    load_kw,        // load (import library file)
    true_kw,        // true
    false_kw,       // false
    super_kw,       // super
    program_kw,     // program
    quote_kw,       // quote
    nothing_kw,     // Nothing
    unknown_kw,     // Unknown

    // Duration units
    days_kw,        // days
    hours_kw,       // hours
    minutes_kw,     // minutes
    seconds_kw,     // seconds

    // Special
    newline,
    indent,         // Tab character for indentation
    eof,
    comment,        // For debugging, usually filtered out

    pub fn toString(self: TokenType) []const u8 {
        return switch (self) {
            .text => "TEXT",
            .number => "NUMBER",
            .money => "MONEY",
            .time => "TIME",
            .boolean => "BOOLEAN",
            .identifier => "IDENTIFIER",
            .assign => "=",
            .plus => "+",
            .minus => "-",
            .multiply => "*",
            .divide => "/",
            .modulo => "%",
            .equal => "=",
            .not_equal => "!=",
            .less_than => "<",
            .greater_than => ">",
            .less_equal => "<=",
            .greater_equal => ">=",
            .and_kw => "and",
            .or_kw => "or",
            .not_kw => "not",
            .dot => ".",
            .comma => ",",
            .semicolon => ";",
            .colon => ":",
            .left_paren => "(",
            .right_paren => ")",
            .left_brace => "{",
            .right_brace => "}",
            .left_bracket => "[",
            .right_bracket => "]",
            .if_kw => "if",
            .else_kw => "else",
            .while_kw => "while",
            .for_kw => "for",
            .in_kw => "in",
            .skip_kw => "skip",
            .breakout_kw => "breakout",
            .to_kw => "to",
            .return_kw => "return",
            .anytime_kw => "anytime",
            .todo_kw => "todo",
            .load_kw => "load",
            .true_kw => "true",
            .false_kw => "false",
            .super_kw => "super",
            .program_kw => "program",
            .quote_kw => "quote",
            .nothing_kw => "Nothing",
            .unknown_kw => "Unknown",
            .days_kw => "days",
            .hours_kw => "hours",
            .minutes_kw => "minutes",
            .seconds_kw => "seconds",
            .newline => "NEWLINE",
            .indent => "INDENT",
            .eof => "EOF",
            .comment => "COMMENT",
        };
    }
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,
    filename: []const u8, // Track source file for error reporting

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}('{s}') at {s}:{}:{}", .{ self.type.toString(), self.lexeme, self.filename, self.line, self.column });
    }
};

pub const LexError = error{
    UnterminatedString,
    UnterminatedComment,
    InvalidCharacter,
    InvalidNumber,
    OutOfMemory,
};

pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: usize,
    column: usize,
    start_column: usize,
    allocator: std.mem.Allocator,
    at_line_start: bool,
    filename: []const u8, // Track current source filename

    pub fn init(allocator: std.mem.Allocator, source: []const u8, filename: []const u8) Lexer {
        return Lexer{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 1,
            .start_column = 1,
            .allocator = allocator,
            .at_line_start = true,
            .filename = filename,
        };
    }

    pub fn scanTokens(self: *Lexer) !std.ArrayList(Token) {
        var tokens = std.ArrayList(Token).init(self.allocator);

        while (!self.isAtEnd()) {
            self.start = self.current;
            self.start_column = self.column;

            if (self.scanToken()) |maybe_token| {
                if (maybe_token) |token| {
                    // Skip comment tokens in normal parsing
                    if (token.type != .comment) {
                        try tokens.append(token);
                    }
                }
            } else |err| {
                return err;
            }
        }

        try tokens.append(self.makeTokenWithLexeme(.eof, ""));

        return tokens;
    }

    fn scanToken(self: *Lexer) LexError!?Token {
        const c = self.advance();

        return switch (c) {
            ' ' => {
                // Handle space-based indentation at line start
                if (self.at_line_start) {
                    return self.scanIndentation();
                } else {
                    return null; // Skip regular spaces
                }
            },
            '\r' => null, // Skip carriage return
            '\t' => self.makeToken(.indent),
            '\n' => {
                self.line += 1;
                self.column = 1;
                self.at_line_start = true;
                return Token{
                    .type = .newline,
                    .lexeme = self.source[self.start..self.current],
                    .line = self.line - 1,
                    .column = self.start_column,
                    .filename = self.filename,
                };
            },

            // Single character tokens
            '(' => self.makeToken(.left_paren),
            ')' => self.makeToken(.right_paren),
            '{' => self.makeToken(.left_brace),
            '}' => self.makeToken(.right_brace),
            '[' => self.makeToken(.left_bracket),
            ']' => self.makeToken(.right_bracket),
            ',' => self.makeToken(.comma),
            ';' => self.makeToken(.semicolon),
            ':' => self.makeToken(.colon),
            '.' => self.makeToken(.dot),
            '+' => self.makeToken(.plus),
            '-' => self.scanMinusOrNumber(),
            '*' => self.makeToken(.multiply),
            '/' => self.makeToken(.divide),
            '%' => self.makeToken(.modulo),

            // Two character tokens
            '!' => {
                if (self.match('=')) {
                    return self.makeToken(.not_equal);
                } else {
                    return LexError.InvalidCharacter;
                }
            },
            '=' => {
                if (self.match('=')) {
                    return self.makeToken(.equal);
                } else {
                    return self.makeToken(.assign);
                }
            },
            '<' => {
                if (self.match('=')) {
                    return self.makeToken(.less_equal);
                } else {
                    return self.makeToken(.less_than);
                }
            },
            '>' => {
                if (self.match('=')) {
                    return self.makeToken(.greater_equal);
                } else {
                    return self.makeToken(.greater_than);
                }
            },

            // Comments
            '#' => self.scanComment(),

            // String literals
            '"' => {
                self.at_line_start = false;
                const token = try self.scanString();
                return token;
            },

            // Money literals
            '$' => {
                self.at_line_start = false;
                const token = try self.scanMoney();
                return token;
            },

            // Time literals
            '@' => {
                self.at_line_start = false;
                const token = try self.scanTime();
                return token;
            },

            else => {
                self.at_line_start = false;
                if (self.isDigit(c)) {
                    const token = try self.scanNumber();
                    return token;
                } else if (self.isAlpha(c)) {
                    const token = try self.scanIdentifier();
                    return token;
                } else {
                    return LexError.InvalidCharacter;
                }
            },
        };
    }

    fn scanComment(self: *Lexer) LexError!?Token {
        // Count initial # symbols (we already consumed the first one)
        var hash_count: usize = 1;
        while (self.peek() == '#') {
            hash_count += 1;
            _ = self.advance();
        }

        if (hash_count == 1) {
            // Single # comment: ends at next # or end of line
            while (self.peek() != '\n' and !self.isAtEnd()) {
                if (self.peek() == '#') {
                    // Found closing #, consume it and end comment
                    _ = self.advance();
                    break;
                }
                _ = self.advance();
            }
        } else {
            // Multiple # comment: ends at same number of consecutive # or end of file
            while (!self.isAtEnd()) {
                const c = self.advance();
                if (c == '\n') {
                    self.line += 1;
                    self.column = 1;
                } else if (c == '#') {
                    // Found a #, check if we have the right number of consecutive #
                    var consecutive_hashes: usize = 1;

                    // Count consecutive # characters
                    while (!self.isAtEnd() and self.peek() == '#') {
                        consecutive_hashes += 1;
                        _ = self.advance();
                    }

                    // If we found matching number of hashes, end comment
                    if (consecutive_hashes == hash_count) {
                        break;
                    }
                    // Otherwise, the hashes we consumed are part of comment content
                }
            }
        }

        return Token{
            .type = .comment,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn scanString(self: *Lexer) LexError!Token {
        // Count consecutive opening quotes (we've already consumed the first one)
        var quote_count: usize = 1;

        // Special case: if we immediately see another quote, check if it's empty string vs multi-quote
        if (self.peek() == '"') {
            // Look ahead one more character to distinguish "" (empty) from ""text"" (multi-quote)
            if (self.peekNext() != '"') {
                // This is an empty string: we have "" - consume the closing quote and return
                _ = self.advance(); // consume the second quote
                return Token{
                    .type = .text,
                    .lexeme = self.source[self.start..self.current],
                    .line = self.line,
                    .column = self.start_column,
                    .filename = self.filename,
                };
            } else {
                // This starts a multi-quote string: continue counting
                while (self.peek() == '"') {
                    quote_count += 1;
                    _ = self.advance();
                }
            }
        }

        // For quote_count = 1: single quote strings like "text"
        // For quote_count > 1: multi-quote strings like ""text"" or """text"""

        // Scan until we find matching closing quotes
        var found_count: usize = 0;
        while (!self.isAtEnd()) {
            if (self.peek() == '"') {
                found_count += 1;
                _ = self.advance();
                if (found_count == quote_count) {
                    break; // Found matching close
                }
            } else {
                if (self.peek() == '\n') {
                    self.line += 1;
                    self.column = 1;
                }
                found_count = 0; // Reset count on non-quote character
                _ = self.advance();
            }
        }

        if (self.isAtEnd() and found_count != quote_count) {
            return LexError.UnterminatedString;
        }

        return Token{
            .type = .text,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn scanMoney(self: *Lexer) LexError!Token {
        // Skip the $, check for optional minus sign, then scan number part
        if (self.peek() == '-') {
            _ = self.advance();
        }
        while (self.isDigit(self.peek()) or self.peek() == '.' or self.peek() == '_') {
            _ = self.advance();
        }

        // Skip whitespace before currency
        while (self.peek() == ' ') {
            _ = self.advance();
        }

        // Scan optional currency designation
        if (self.isAlpha(self.peek())) {
            while (self.isAlphaNumeric(self.peek())) {
                _ = self.advance();
            }
        }

        return Token{
            .type = .money,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn scanTime(self: *Lexer) LexError!Token {
        // Skip the @, then scan time/date part
        if (self.isAlpha(self.peek())) {
            // Handle @now
            while (self.isAlpha(self.peek())) {
                _ = self.advance();
            }
        } else {
            // Handle numeric time/date formats including ISO 8601 datetime (T separator)
            while (self.isDigit(self.peek()) or self.peek() == '-' or self.peek() == ':' or self.peek() == ' ' or self.peek() == 'T') {
                _ = self.advance();
            }
        }

        return Token{
            .type = .time,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn scanMinusOrNumber(self: *Lexer) LexError!?Token {
        // If next character is digit, this could be a negative number
        if (self.isDigit(self.peek())) {
            const token = try self.scanNumber();
            return token;
        } else {
            return self.makeToken(.minus);
        }
    }

    fn scanNumber(self: *Lexer) LexError!Token {
        // Scan integer part
        while (self.isDigit(self.peek()) or self.peek() == '_') {
            _ = self.advance();
        }

        // Look for decimal part
        if (self.peek() == '.' and self.isDigit(self.peekNext())) {
            _ = self.advance(); // Consume the '.'
            while (self.isDigit(self.peek()) or self.peek() == '_') {
                _ = self.advance();
            }
        }

        return Token{
            .type = .number,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn scanIdentifier(self: *Lexer) LexError!Token {
        while (self.isAlphaNumeric(self.peek()) or self.peek() == '_') {
            _ = self.advance();
        }

        const text = self.source[self.start..self.current];
        const token_type = self.identifierType(text);

        return Token{
            .type = token_type,
            .lexeme = text,
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn identifierType(self: *Lexer, text: []const u8) TokenType {
        _ = self;

        // Check keywords
        const keywords = std.ComptimeStringMap(TokenType, .{
            .{ "and", .and_kw },
            .{ "or", .or_kw },
            .{ "not", .not_kw },
            .{ "if", .if_kw },
            .{ "else", .else_kw },
            .{ "while", .while_kw },
            .{ "for", .for_kw },
            .{ "in", .in_kw },
            .{ "skip", .skip_kw },
            .{ "breakout", .breakout_kw },
            .{ "to", .to_kw },
            .{ "return", .return_kw },
            .{ "anytime", .anytime_kw },
            .{ "todo", .todo_kw },
            .{ "load", .load_kw },
            .{ "true", .true_kw },
            .{ "false", .false_kw },
            .{ "super", .super_kw },
            .{ "program", .program_kw },
            .{ "quote", .quote_kw },
            .{ "Nothing", .nothing_kw },
            .{ "Unknown", .unknown_kw },
            .{ "days", .days_kw },
            .{ "hours", .hours_kw },
            .{ "minutes", .minutes_kw },
            .{ "seconds", .seconds_kw },
        });

        return keywords.get(text) orelse .identifier;
    }

    // Helper functions
    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        self.column += 1;
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        self.column += 1;
        return true;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Lexer) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn isDigit(self: *Lexer, c: u8) bool {
        _ = self;
        return c >= '0' and c <= '9';
    }

    fn isAlpha(self: *Lexer, c: u8) bool {
        _ = self;
        return (c >= 'a' and c <= 'z') or
               (c >= 'A' and c <= 'Z') or
               c == '_';
    }

    fn isAlphaNumeric(self: *Lexer, c: u8) bool {
        return self.isAlpha(c) or self.isDigit(c);
    }

    fn scanIndentation(self: *Lexer) LexError!?Token {
        // Count leading spaces at the start of the line
        var space_count: u32 = 1; // We already consumed one space

        // Continue counting spaces
        while (!self.isAtEnd() and self.peek() == ' ') {
            _ = self.advance();
            space_count += 1;
        }

        self.at_line_start = false;

        // Generate INDENT token for every 4 spaces
        const indent_levels = space_count / 4;
        if (indent_levels > 0) {
            // For now, just return one token representing all indentation
            // The parser will need to handle different indentation levels
            return Token{
                .type = .indent,
                .lexeme = self.source[self.start..self.current],
                .line = self.line,
                .column = self.start_column,
                .filename = self.filename,
            };
        } else {
            // Less than 4 spaces, treat as regular whitespace
            return null;
        }
    }

    fn makeToken(self: *Lexer, token_type: TokenType) Token {
        self.at_line_start = false;
        return Token{
            .type = token_type,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }

    fn makeTokenWithLexeme(self: *Lexer, token_type: TokenType, lexeme: []const u8) Token {
        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .line = self.line,
            .column = self.start_column,
            .filename = self.filename,
        };
    }
};

// Test function
pub fn testLexer() !void {
    const allocator = std.heap.page_allocator;

    const test_source =
        \\# Test MBL program
        \\customer = { name: "John", balance: $500.50 }
        \\
        \\low_balance_alert customer.balance < $100:
        \\	program.write("Warning: Low balance")
        \\
        \\process_payment(amount):
        \\	if amount > customer.balance: return false
        \\	customer.balance -= amount; return true
    ;

    var lexer = Lexer.init(allocator, test_source, "test.mbl");
    const tokens = try lexer.scanTokens();
    defer tokens.deinit();

    std.log.info("Tokenized {} tokens:", .{tokens.items.len});
    for (tokens.items) |token| {
        std.log.info("  {}", .{token});
    }
}
