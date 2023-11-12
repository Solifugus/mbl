// lexer/lexer.go

package lexer

import (
	"fmt"
	"strings"
	"unicode"
)

// TokenType represents the type of a token.
type TokenType int

const (
	Text TokenType = iota
	Numeric
	Alphanumeric
	NewLine
	Tab
	Symbol
)

// Token represents a token in the source code.
type Token struct {
	Type  TokenType
	Value string
}

// Lexer is responsible for tokenizing the source code.
type Lexer struct {
	input  string
	tokens []Token
	pos    int
}

// NewLexer creates a new Lexer instance.
func NewLexer(input string) *Lexer {
	return &Lexer{
		input:  input,
		tokens: make([]Token, 0),
		pos:    0,
	}
}

// LexTokenizes the source code and returns a slice of tokens.
func (l *Lexer) Lex() ([]Token, error) {
	for l.pos < len(l.input) {
		r := l.input[l.pos]

		switch {
		case unicode.IsSpace(r):
			l.consumeWhitespace()
		case r == '"':
			err := l.consumeText()
			if err != nil {
				return nil, err
			}
		case unicode.IsDigit(r) || (r == '-' && unicode.IsDigit(l.peek())):
			l.consumeNumeric()
		case unicode.IsLetter(r):
			l.consumeAlphanumeric()
		case r == '\n':
			l.consumeNewLine()
		case r == '\t':
			l.consumeTab()
		default:
			l.consumeSymbol()
		}
	}

	return l.tokens, nil
}

// Helper function to consume consecutive whitespace characters.
func (l *Lexer) consumeWhitespace() {
	for l.pos < len(l.input) && unicode.IsSpace(l.input[l.pos]) {
		l.pos++
	}
}

// Helper function to consume text within quotes.
func (l *Lexer) consumeText() error {
	l.pos++ // Skip the opening quote

	start := l.pos
	for l.pos < len(l.input) && l.input[l.pos] != '"' {
		l.pos++
	}

	if l.pos == len(l.input) {
		return fmt.Errorf("unclosed quote")
	}

	text := l.input[start:l.pos]
	l.tokens = append(l.tokens, Token{Type: Text, Value: text})

	l.pos++ // Skip the closing quote
	return nil
}

// Helper function to consume numeric literals.
func (l *Lexer) consumeNumeric() {
	start := l.pos

	for l.pos < len(l.input) && (unicode.IsDigit(l.input[l.pos]) || l.input[l.pos] == '_' || l.input[l.pos] == '.') {
		l.pos++
	}

	numeric := l.input[start:l.pos]
	l.tokens = append(l.tokens, Token{Type: Numeric, Value: numeric})
}

// Helper function to consume alphanumeric tokens.
func (l *Lexer) consumeAlphanumeric() {
	start := l.pos

	for l.pos < len(l.input) && (unicode.IsLetter(l.input[l.pos]) || unicode.IsDigit(l.input[l.pos])) {
		l.pos++
	}

	alphanumeric := l.input[start:l.pos]
	l.tokens = append(l.tokens, Token{Type: Alphanumeric, Value: alphanumeric})
}

// Helper function to consume consecutive new line characters.
func (l *Lexer) consumeNewLine() {
	count := 0

	for l.pos < len(l.input) && l.input[l.pos] == '\n' {
		l.pos++
		count++
	}

	l.tokens = append(l.tokens, Token{Type: NewLine, Value: strings.Repeat("\n", count)})
}

// Helper function to consume consecutive tab characters.
func (l *Lexer) consumeTab() {
	count := 0

	for l.pos < len(l.input) && l.input[l.pos] == '\t' {
		l.pos++
		count++
	}

	l.tokens = append(l.tokens, Token{Type: Tab, Value: strings.Repeat("\t", count)})
}

// Helper function to consume symbol tokens.
func (l *Lexer) consumeSymbol() {
	symbol := string(l.input[l.pos])
	l.tokens = append(l.tokens, Token{Type: Symbol, Value: symbol})
	l.pos++
}

// Helper function to peek at the next character without consuming it.
func (l *Lexer) peek() rune {
	if l.pos+1 < len(l.input) {
		return rune(l.input[l.pos+1])
	}
	return 0
}

