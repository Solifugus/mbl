// cmd/mblinterpreter/main.go

package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"github.com/Solifugus/mbl/pkg/lexer"
	"github.com/Solifugus/mbl/pkg/placer"
	"github.com/Solifugus/mbl/pkg/runner"
)

func main() {
	// Check if a file path is provided as a command-line argument
	if len(os.Args) < 2 {
		fmt.Println("Usage: mblinterpreter <file_path>")
		os.Exit(1)
	}

	// Read the MBL source code from the file
	filePath := os.Args[1]
	sourceCode, err := ioutil.ReadFile(filePath)
	if err != nil {
		log.Fatal(err)
	}

	// Create a lexer and tokenize the source code
	lexer := lexer.NewLexer(string(sourceCode))
	tokens, err := lexer.Lex()
	if err != nil {
		log.Fatal(err)
	}

	// Create a placer and place tokens in the hierarchical data structure
	placer := placer.NewPlacer()
	err = placer.PlaceTokens(tokens)
	if err != nil {
		log.Fatal(err)
	}

	// Create a runner and execute functions at specified places in storage
	runner := runner.NewRunner()
	err = runner.Run(tokens)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("MBL program executed successfully!")
}
