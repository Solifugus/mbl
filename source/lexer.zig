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
    function_kw,    // function (implicit in syntax)
    if_kw,          // if
    then_kw,        // then
    else_kw,        // else
    end_kw,         // end
    while_kw,       // while
    for_kw,         // for
    in_kw,          // in
    break_kw,       // break
    continue_kw,    // continue
    to_kw,          // to (for ranges)
    return_kw,      // return
    goto_kw,        // goto
    true_kw,        // true
    false_kw,       // false
    super_kw,       // super
    program_kw,     // program
    quote_kw,       // quote
    nothing_kw,     // Nothing
    unknown_kw,     // Unknown
    empty_kw,       // empty

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
            .then_kw => "then",
            .else_kw => "else",
            .end_kw => "end",
            .while_kw => "while",
            .for_kw => "for",
            .in_kw => "in",
            .break_kw => "break",
            .continue_kw => "continue",
            .to_kw => "to",
            .return_kw => "return",
            .goto_kw => "goto",
            .true_kw => "true",
            .false_kw => "false",
            .super_kw => "super",
            .program_kw => "program",
            .quote_kw => "quote",
            .nothing_kw => "Nothing",
            .unknown_kw => "Unknown",
            .empty_kw => "empty",
            .days_kw => "days",
            .hours_kw => "hours",
            .minutes_kw => "minutes",
            .seconds_kw => "seconds",
            .newline => "NEWLINE",
            .indent => "INDENT",
            .eof => "EOF",
            .comment => "COMMENT",
            else => "UNKNOWN",
        };
    }
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}('{s}') at {}:{}", .{ self.type.toString(), self.lexeme, self.line, self.column });
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

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 1,
            .start_column = 1,
            .allocator = allocator,
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

        try tokens.append(Token{
            .type = .eof,
            .lexeme = "",
            .line = self.line,
            .column = self.column,
        });

        return tokens;
    }

    fn scanToken(self: *Lexer) LexError!?Token {
        const c = self.advance();

        return switch (c) {
            ' ', '\r' => null, // Skip whitespace (except tabs and newlines)
            '\t' => Token{
                .type = .indent,
                .lexeme = self.source[self.start..self.current],
                .line = self.line,
                .column = self.start_column,
            },
            '\n' => {
                self.line += 1;
                self.column = 1;
                return Token{
                    .type = .newline,
                    .lexeme = self.source[self.start..self.current],
                    .line = self.line - 1,
                    .column = self.start_column,
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
                const token = try self.scanString();
                return token;
            },

            // Money literals
            '$' => {
                const token = try self.scanMoney();
                return token;
            },

            // Time literals
            '@' => {
                const token = try self.scanTime();
                return token;
            },

            else => {
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
        // Count initial # symbols
        var hash_count: usize = 1;
        while (self.peek() == '#') {
            hash_count += 1;
            _ = self.advance();
        }

        if (hash_count == 1) {
            // Single-line comment - continues to newline OR ends with closing #
            // Look for immediate closing # (like "##") vs # later in line (like "# text # more")
            const immediate_close = self.peek() == '#';
            if (immediate_close) {
                // Handle "##" case - consume the closing #
                _ = self.advance();
            } else {
                // Handle "# comment..." case - go until newline or find closing #
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    if (self.peek() == '#') {
                        // Check if this should terminate the comment
                        // For single hash, a standalone # terminates the comment
                        const next_pos = self.current + 1;
                        if (next_pos >= self.source.len or
                            self.source[next_pos] == ' ' or
                            self.source[next_pos] == '\t' or
                            self.source[next_pos] == '\n') {
                            // This # is followed by whitespace/end, so it terminates
                            _ = self.advance();
                            break;
                        }
                    }
                    _ = self.advance();
                }
            }
        } else {
            // Multi-line comment - look for matching number of consecutive #
            // Track if we've seen a newline to distinguish single-line vs multi-line
            var seen_newline = false;

            while (!self.isAtEnd()) {
                const c = self.advance();
                if (c == '#') {
                    // For multi-line comments, closing # must be at start of line
                    // For single-line comments, closing # can be anywhere
                    var is_valid_closing_position = false;
                    if (seen_newline) {
                        // Multi-line mode: # must be at start of line
                        if (self.current > 1) {
                            const prev_char = self.source[self.current - 2];
                            is_valid_closing_position = (prev_char == '\n' or prev_char == '\r');
                        } else {
                            is_valid_closing_position = true; // Very beginning of input
                        }
                    } else {
                        // Single-line mode: # can be anywhere
                        is_valid_closing_position = true;
                    }

                    if (is_valid_closing_position) {
                        // Count consecutive # characters starting from current position
                        var consecutive_hashes: usize = 1; // We already found one

                        // Look ahead for more consecutive hashes
                        while (!self.isAtEnd() and self.peek() == '#') {
                            consecutive_hashes += 1;
                            _ = self.advance();
                        }

                        // If we found the matching number of hashes, we're done
                        if (consecutive_hashes == hash_count) {
                            // For multi-line comments ending with ### End..., consume the rest of line
                            if (seen_newline and !self.isAtEnd() and self.peek() != '\n' and self.peek() != '\r') {
                                // Consume the rest of the line (like "End multi-line comment")
                                while (!self.isAtEnd() and self.peek() != '\n' and self.peek() != '\r') {
                                    _ = self.advance();
                                }
                            }
                            break;
                        }
                    }
                    // Otherwise continue scanning (the hashes we consumed are part of comment content)
                } else if (c == '\n') {
                    seen_newline = true;
                    self.line += 1;
                    self.column = 1;
                }
            }
        }

        return Token{
            .type = .comment,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
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
        };
    }

    fn scanMoney(self: *Lexer) LexError!Token {
        // Skip the $, then scan number part
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
            .{ "then", .then_kw },
            .{ "else", .else_kw },
            .{ "end", .end_kw },
            .{ "while", .while_kw },
            .{ "for", .for_kw },
            .{ "in", .in_kw },
            .{ "break", .break_kw },
            .{ "continue", .continue_kw },
            .{ "to", .to_kw },
            .{ "return", .return_kw },
            .{ "goto", .goto_kw },
            .{ "true", .true_kw },
            .{ "false", .false_kw },
            .{ "super", .super_kw },
            .{ "program", .program_kw },
            .{ "quote", .quote_kw },
            .{ "Nothing", .nothing_kw },
            .{ "Unknown", .unknown_kw },
            .{ "empty", .empty_kw },
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

    fn makeToken(self: *Lexer, token_type: TokenType) Token {
        return Token{
            .type = token_type,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.start_column,
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

    var lexer = Lexer.init(allocator, test_source);
    const tokens = try lexer.scanTokens();
    defer tokens.deinit();

    std.log.info("Tokenized {} tokens:", .{tokens.items.len});
    for (tokens.items) |token| {
        std.log.info("  {}", .{token});
    }
}
