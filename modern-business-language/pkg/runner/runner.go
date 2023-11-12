// runner/runner.go

package runner

import (
	"fmt"
)

// Runner is responsible for executing functions at specified places in storage.
type Runner struct {
	// Add any necessary fields for maintaining the execution state.
}

// NewRunner creates a new Runner instance.
func NewRunner() *Runner {
	return &Runner{}
}

// Run executes the functions at specified places in storage.
func (r *Runner) Run(tokens []Token) error {
	// Implement the logic to execute functions at specified places in storage.
	// Iterate through the tokens and execute their associated functions.

	for _, token := range tokens {
		err := r.executeToken(token)
		if err != nil {
			return err
		}
	}

	return nil
}

// executeToken executes the function associated with a token.
func (r *Runner) executeToken(token Token) error {
	// Implement the logic to execute the function associated with the token.
	// You may need to pass values and manage the execution flow.

	switch token.Type {
	case Text:
		// Handle Text token execution logic.
	case Numeric:
		// Handle Numeric token execution logic.
	case Alphanumeric:
		// Handle Alphanumeric token execution logic.
	case NewLine:
		// Handle NewLine token execution logic.
	case Tab:
		// Handle Tab token execution logic.
	case Symbol:
		// Handle Symbol token execution logic.
	default:
		return fmt.Errorf("unknown token type: %v", token.Type)
	}

	return nil
}

// Add any additional helper functions or methods as needed for executing functions in the storage.

