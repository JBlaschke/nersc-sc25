package main

import (
	"fmt"
	"os"

	"github.com/hashicorp/hcl/v2/hclparse"
	"github.com/spf13/cobra"
)

var (
	validate bool
)

var rootCmd = &cobra.Command{
	Use:   "read_hcl <file>",
	Short: "Read and display an HCL file",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		return readHCLFile(args[0], validate)
	},
}

func init() {
	rootCmd.Flags().BoolVarP(&validate, "validate", "v", false, "validate HCL syntax")
}

func readHCLFile(filename string, validate bool) error {
	// Read the file
	content, err := os.ReadFile(filename)
	if err != nil {
		return fmt.Errorf("error reading file: %w", err)
	}

	// Display the content
	fmt.Println("File contents:")
	fmt.Println("==============")
	fmt.Println(string(content))
	fmt.Println()

	// Optionally validate
	if validate {
		fmt.Println("Validating HCL syntax...")
		fmt.Println("=======================")
		
		parser := hclparse.NewParser()
		_, diags := parser.ParseHCL(content, filename)
		
		if diags.HasErrors() {
			return fmt.Errorf("HCL syntax errors:\n%s", diags.Error())
		}
		
		fmt.Println("✓ Valid HCL syntax")
	}

	return nil
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
