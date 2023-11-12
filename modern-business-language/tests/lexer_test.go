// tests/lexer_test.go

package tests

import (
	"reflect"
	"testing"

	"github.com/Solifugus/mbl/pkg/lexer"
)

func TestLexerLex(t *testing.T) {
	testCases := []struct {
		input  string
		tokens []lexer.Token
	}{
		{
			input: "Text123 \"String with spaces\" 42\nAlphanumeric",
			tokens: []lexer.Token{
				{Type: lexer.Alphanumeric, Value: "Text123"},
				{Type: lexer.Text, Value: "String with spaces"},
				{Type: lexer.Numeric, Value: "42"},
				{Type: lexer.NewLine, Value: "\n"},
				{Type: lexer.Alphanumeric, Value: "Alphanumeric"},
			},
		},
		// Add more test cases as needed
	}

	for _, testCase := range testCases {
		t.Run(testCase.input, func(t *testing.T) {
			l := lexer.NewLexer(testCase.input)
			tokens, err := l.Lex()
			if err != nil {
				t.Errorf("unexpected error: %v", err)
			}

			if !reflect.DeepEqual(tokens, testCase.tokens) {
				t.Errorf("expected tokens %v, got %v", testCase.tokens, tokens)
			}
		})
	}
}
