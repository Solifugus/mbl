#include "lexer/lexer.hpp"
#include "lexer/token.hpp"
#include <gtest/gtest.h>
#include <vector>
#include <chrono>
#include <random>

using namespace mbl;

class LexerTest : public ::testing::Test {
protected:
    std::vector<Token> scan(std::string_view source) {
        Lexer lexer(source);
        return lexer.scanTokens();
    }

    void expectTokens(const std::vector<Token>& tokens, const std::vector<TokenType> expected) {
        ASSERT_EQ(tokens.size(), expected.size());
        for (size_t i = 0; i < tokens.size(); i++) {
            EXPECT_EQ(tokens[i].type(), expected[i]);
        }
    }

    void expectToken(const Token& token, TokenType type, std::string_view lexeme, int line, int column) {
        EXPECT_EQ(token.type(), type);
        EXPECT_EQ(token.lexeme(), lexeme);
        EXPECT_EQ(token.line(), line);
        EXPECT_EQ(token.column(), column);
    }
};

// Basic Input Tests
TEST_F(LexerTest, EmptyInput) {
    auto tokens = scan("");
    expectTokens(tokens, {TokenType::END_OF_FILE});
    expectToken(tokens[0], TokenType::END_OF_FILE, "", 1, 1);
}

TEST_F(LexerTest, Whitespace) {
    auto tokens = scan("   \t\r\n");
    expectTokens(tokens, {TokenType::NEWLINE, TokenType::END_OF_FILE});
    expectToken(tokens[0], TokenType::NEWLINE, "\n", 1, 5);
    expectToken(tokens[1], TokenType::END_OF_FILE, "", 2, 1);
}

// Keyword Tests with Lexeme Verification
TEST_F(LexerTest, Keywords) {
    auto tokens = scan("if then else while do for in function return true false unknown");
    expectTokens(tokens, {
        TokenType::IF,
        TokenType::THEN,
        TokenType::ELSE,
        TokenType::WHILE,
        TokenType::DO,
        TokenType::FOR,
        TokenType::IN,
        TokenType::FUNCTION,
        TokenType::RETURN,
        TokenType::BOOLEAN,
        TokenType::BOOLEAN,
        TokenType::UNKNOWN,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::IF, "if", 1, 1);
    expectToken(tokens[1], TokenType::THEN, "then", 1, 4);
    expectToken(tokens[2], TokenType::ELSE, "else", 1, 9);
    expectToken(tokens[3], TokenType::WHILE, "while", 1, 14);
}

// Number Tests with Lexeme Verification
TEST_F(LexerTest, Numbers) {
    auto tokens = scan("123 456.789 1_234_567");
    expectTokens(tokens, {
        TokenType::NUMBER,
        TokenType::NUMBER,
        TokenType::NUMBER,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::NUMBER, "123", 1, 1);
    expectToken(tokens[1], TokenType::NUMBER, "456.789", 1, 5);
    expectToken(tokens[2], TokenType::NUMBER, "1_234_567", 1, 13);
}

// Text Tests with Line/Column Tracking
TEST_F(LexerTest, Text) {
    auto tokens = scan("\"Hello, World!\" \"Multi\nline\"");
    expectTokens(tokens, {
        TokenType::TEXT,
        TokenType::TEXT,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::TEXT, "\"Hello, World!\"", 1, 1);
    expectToken(tokens[1], TokenType::TEXT, "\"Multi\nline\"", 1, 16);
}

// Special Types with Position Tracking
TEST_F(LexerTest, SpecialTypes) {
    auto tokens = scan("@2024-03-14 $123.45");
    expectTokens(tokens, {
        TokenType::TIME,
        TokenType::MONEY,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::TIME, "@2024-03-14", 1, 1);
    expectToken(tokens[1], TokenType::MONEY, "$123.45", 1, 13);
}

// Comments with Line/Column Tracking
TEST_F(LexerTest, Comments) {
    auto tokens = scan("# Single line comment #\n## Multi\nline\ncomment ##");
    expectTokens(tokens, {
        TokenType::COMMENT_START,
        TokenType::COMMENT_END,
        TokenType::NEWLINE,
        TokenType::COMMENT_START,
        TokenType::COMMENT_END,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::COMMENT_START, "#", 1, 1);
    expectToken(tokens[1], TokenType::COMMENT_END, "#", 1, 21);
    expectToken(tokens[2], TokenType::NEWLINE, "\n", 1, 22);
}

// Edge Cases
TEST_F(LexerTest, EdgeCases) {
    // Test empty comments
    auto tokens1 = scan("##");
    expectTokens(tokens1, {TokenType::COMMENT_START, TokenType::COMMENT_END, TokenType::END_OF_FILE});
    
    // Test unterminated comment
    auto tokens2 = scan("### Comment");
    expectTokens(tokens2, {TokenType::COMMENT_START, TokenType::ERROR, TokenType::END_OF_FILE});
    
    // Test mixed text and operators
    auto tokens3 = scan("x = 42\ny = \"Hello\"\nz > 10");
    expectTokens(tokens3, {
        TokenType::TEXT,
        TokenType::ASSIGN,
        TokenType::NUMBER,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::ASSIGN,
        TokenType::TEXT,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::GREATER,
        TokenType::NUMBER,
        TokenType::END_OF_FILE
    });
}

// Complex Examples with Full Verification
TEST_F(LexerTest, ComplexExample) {
    auto tokens = scan(R"(
if x > 10 then
    y = "Hello"
    computer.write(y)
else
    z = 42
end
)");
    expectTokens(tokens, {
        TokenType::IF,
        TokenType::TEXT,
        TokenType::GREATER,
        TokenType::NUMBER,
        TokenType::THEN,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::ASSIGN,
        TokenType::TEXT,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::DOT,
        TokenType::TEXT,
        TokenType::LEFT_PAREN,
        TokenType::TEXT,
        TokenType::RIGHT_PAREN,
        TokenType::NEWLINE,
        TokenType::ELSE,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::ASSIGN,
        TokenType::NUMBER,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::NEWLINE,
        TokenType::END_OF_FILE
    });
    
    // Verify specific tokens
    expectToken(tokens[0], TokenType::IF, "if", 2, 1);
    expectToken(tokens[1], TokenType::TEXT, "x", 2, 4);
    expectToken(tokens[2], TokenType::GREATER, ">", 2, 6);
    expectToken(tokens[3], TokenType::NUMBER, "10", 2, 8);
}

// Line/Column Tracking Tests
TEST_F(LexerTest, LineColumnTracking) {
    auto tokens = scan(R"(
x = 42
y = "Hello"
z = @2024-03-14
)");
    
    expectToken(tokens[0], TokenType::TEXT, "x", 2, 1);
    expectToken(tokens[1], TokenType::ASSIGN, "=", 2, 3);
    expectToken(tokens[2], TokenType::NUMBER, "42", 2, 5);
    expectToken(tokens[3], TokenType::NEWLINE, "\n", 2, 7);
    
    expectToken(tokens[4], TokenType::TEXT, "y", 3, 1);
    expectToken(tokens[5], TokenType::ASSIGN, "=", 3, 3);
    expectToken(tokens[6], TokenType::TEXT, "\"Hello\"", 3, 5);
    expectToken(tokens[7], TokenType::NEWLINE, "\n", 3, 12);
    
    expectToken(tokens[8], TokenType::TEXT, "z", 4, 1);
    expectToken(tokens[9], TokenType::ASSIGN, "=", 4, 3);
    expectToken(tokens[10], TokenType::TIME, "@2024-03-14", 4, 5);
}

// Recursive Comments Test
TEST_F(LexerTest, RecursiveComments) {
    auto tokens = scan(R"(
# This is a comment #
# Another comment with # inside #
)");
    expectTokens(tokens, {
        TokenType::NEWLINE,
        TokenType::COMMENT_START,
        TokenType::COMMENT_END,
        TokenType::NEWLINE,
        TokenType::COMMENT_START,
        TokenType::COMMENT_END,
        TokenType::NEWLINE,
        TokenType::END_OF_FILE
    });
}

// Multi-Quote Strings Test
TEST_F(LexerTest, MultiQuoteStrings) {
    auto tokens = scan(R"(
"This is a \"quoted\" string"
"String with \"nested\" quotes"
)");
    expectTokens(tokens, {
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::NEWLINE,
        TokenType::TEXT,
        TokenType::NEWLINE,
        TokenType::END_OF_FILE
    });
}

// Money with Currency Test
TEST_F(LexerTest, MoneyWithCurrency) {
    auto tokens = scan("$123.45USD $1,234.56EUR");
    expectTokens(tokens, {
        TokenType::MONEY,
        TokenType::MONEY,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::MONEY, "$123.45USD", 1, 1);
    expectToken(tokens[1], TokenType::MONEY, "$1,234.56EUR", 1, 11);
}

// Time Formats Test
TEST_F(LexerTest, TimeFormats) {
    auto tokens = scan("@09:30 @14:45:30 @2024-03-14T15:30:00");
    expectTokens(tokens, {
        TokenType::TIME,
        TokenType::TIME,
        TokenType::TIME,
        TokenType::END_OF_FILE
    });
    
    expectToken(tokens[0], TokenType::TIME, "@09:30", 1, 1);
    expectToken(tokens[1], TokenType::TIME, "@14:45:30", 1, 8);
    expectToken(tokens[2], TokenType::TIME, "@2024-03-14T15:30:00", 1, 17);
}

// Large Input Performance Test
TEST_F(LexerTest, LargeInputPerformance) {
    std::string input;
    for (int i = 0; i < 10000; i++) {
        input += "x = 42\n";
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    auto tokens = scan(input);
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    EXPECT_LT(duration.count(), 1000);  // Should process in less than 1 second
    
    EXPECT_EQ(tokens.size(), 40001);  // 10000 * 4 tokens per line + EOF
    for (size_t i = 0; i < tokens.size() - 1; i += 4) {
        expectToken(tokens[i], TokenType::TEXT, "x", (i / 4) + 1, 1);
        expectToken(tokens[i + 1], TokenType::ASSIGN, "=", (i / 4) + 1, 3);
        expectToken(tokens[i + 2], TokenType::NUMBER, "42", (i / 4) + 1, 5);
        expectToken(tokens[i + 3], TokenType::NEWLINE, "\n", (i / 4) + 1, 7);
    }
}

// Memory Usage Test
TEST_F(LexerTest, MemoryUsage) {
    std::string input;
    for (int i = 0; i < 1000; i++) {
        input += "\"This is a very long string that should be efficiently handled by the lexer without excessive memory allocation\"\n";
    }
    
    auto tokens = scan(input);
    EXPECT_EQ(tokens.size(), 2001);  // 1000 * 2 tokens per line (TEXT + NEWLINE) + EOF
    
    // Verify the first and last tokens
    expectToken(tokens[0], TokenType::TEXT, "\"This is a very long string that should be efficiently handled by the lexer without excessive memory allocation\"", 1, 1);
    expectToken(tokens[tokens.size() - 2], TokenType::NEWLINE, "\n", 1000, 96);
}

// Stress Test with Random Input
TEST_F(LexerTest, StressTest) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(32, 126);  // Printable ASCII characters
    
    std::string input;
    for (int i = 0; i < 10000; i++) {
        char c = static_cast<char>(dis(gen));
        input += c;
        if (i % 100 == 0) input += '\n';
    }
    
    auto tokens = scan(input);
    EXPECT_FALSE(Lexer(input).hadError());
}

// Error Recovery Test
TEST_F(LexerTest, ErrorRecovery) {
    auto tokens = scan(R"(
if x > 10 then
    y = "Hello
    z = 42
end
)");
    
    EXPECT_TRUE(Lexer(R"(
if x > 10 then
    y = "Hello
    z = 42
end
)").hadError());
    
    // Verify that lexing continues after the error
    expectToken(tokens[0], TokenType::IF, "if", 2, 1);
    expectToken(tokens[1], TokenType::TEXT, "x", 2, 4);
    expectToken(tokens[2], TokenType::GREATER, ">", 2, 6);
    expectToken(tokens[3], TokenType::NUMBER, "10", 2, 8);
    expectToken(tokens[4], TokenType::THEN, "then", 2, 11);
    expectToken(tokens[5], TokenType::NEWLINE, "\n", 2, 15);
    expectToken(tokens[6], TokenType::TEXT, "y", 3, 5);
    expectToken(tokens[7], TokenType::ASSIGN, "=", 3, 7);
    expectToken(tokens[8], TokenType::ERROR, "Unterminated string", 3, 9);
} 