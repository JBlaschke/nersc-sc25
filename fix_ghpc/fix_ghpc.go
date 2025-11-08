package main

import (
    "fmt"
    "os"
    "strings"
	"path/filepath"

    "github.com/hashicorp/hcl/v2"
    "github.com/hashicorp/hcl/v2/hclwrite"
    "github.com/hashicorp/hcl/v2/hclparse"
    "github.com/spf13/cobra"
    "github.com/zclconf/go-cty/cty"
)

var rootCmd = &cobra.Command{
    Use:   "read_hcl <file>",
    Short: "Read and display an HCL file",
    Args:  cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        return processHCLFile(args[0])
    },
}

func formatValue(val cty.Value) string {
    if val.IsNull() {
        return "null"
    }

    switch val.Type() {
    case cty.String:
        return fmt.Sprintf("%q", val.AsString())
    case cty.Number:
        return val.AsBigFloat().String()
    case cty.Bool:
        return fmt.Sprintf("%t", val.True())
    }

    // Handle lists/tuples
    if val.Type().IsListType() || val.Type().IsTupleType() {
        var items []string
        it := val.ElementIterator()
        for it.Next() {
            _, v := it.Element()
            items = append(items, formatValue(v))
        }
        return fmt.Sprintf("[%s]", joinStrings(items, ", "))
    }

    // Handle maps/objects
    if val.Type().IsMapType() || val.Type().IsObjectType() {
        var items []string
        it := val.ElementIterator()
        for it.Next() {
            k, v := it.Element()
            items = append(items, fmt.Sprintf("%s = %s", formatValue(k), formatValue(v)))
        }
        return fmt.Sprintf("{%s}", joinStrings(items, ", "))
    }

    return val.GoString()
}

func joinStrings(items []string, sep string) string {
    if len(items) == 0 {
        return ""
    }
    result := items[0]
    for i := 1; i < len(items); i++ {
        result += sep + items[i]
    }
    return result
}

func printVariables(attrs map[string]*hcl.Attribute) {
    fmt.Println("")
    fmt.Println("Variables and Values:")
    fmt.Println("=====================")
    
    if len(attrs) == 0 {
        fmt.Println("(no attributes found)")
        return
    }

    for name, attr := range attrs {
        val, diags := attr.Expr.Value(nil)
        if diags.HasErrors() {
            fmt.Printf("%-20s <error: %s>\n", name+":", diags.Error())
            continue
        }

        fmt.Printf("%-20s %s (type: %s)\n", name+":", formatValue(val), val.Type().FriendlyName())
    }

    return
}

// PrefixRule defines a single prefix replacement rule
type PrefixRule struct {
	OldPrefix []string
	NewPrefix []string
}

// PathFixer holds multiple replacement rules
type PathFixer struct {
	Rules []PrefixRule
}

// NewPathFixer creates a new PathFixer
func NewPathFixer(rules []PrefixRule) *PathFixer {
	return &PathFixer{Rules: rules}
}

// FixPath applies the first matching transformation
func (pf *PathFixer) FixPath(path string) string {
	// Split path into tokens
	tokens := strings.Split(filepath.ToSlash(path), "/")
	
	// Try each rule
	for _, rule := range pf.Rules {
		if hasPrefix(tokens, rule.OldPrefix) {
			// Replace the prefix
			remainingTokens := tokens[len(rule.OldPrefix):]
			newTokens := append(rule.NewPrefix, remainingTokens...)
			return strings.Join(newTokens, "/")
		}
	}
	
	return path // No change needed
}

// hasPrefix checks if tokens starts with prefix
func hasPrefix(tokens, prefix []string) bool {
	if len(tokens) < len(prefix) {
		return false
	}
	
	for i, p := range prefix {
		if tokens[i] != p {
			return false
		}
	}
	
	return true
}

func fixPath(path string) string {
	fixer := NewPathFixer([]PrefixRule{
		{
			OldPrefix: []string{"..", ".ghpc"},
			NewPrefix: []string{"..", "..", ".ghpc"},
		},
	})
	return fixer.FixPath(path)
}

func fixShellScripts(
        attrs map[string]*hcl.Attribute, body *hclwrite.Body,
) (bool, error) {
	// Look for shell_scripts attribute
	shellScripts, exists := attrs["shell_scripts"]
	if !exists {
        return false, fmt.Errorf("No 'shell_scripts' variable found")
	}

	// Get the value
	val, diags := shellScripts.Expr.Value(nil)
	if diags.HasErrors() {
		return false, fmt.Errorf(
            "Error reading shell_scripts: %s\n", diags.Error(),
        )
	}

	// Check if it's a list
	if !val.Type().IsListType() && !val.Type().IsTupleType() {
		return false, fmt.Errorf("shell_scripts is not a list")
	}

    fmt.Println("")
    fmt.Println("Found target: 'shell_scripts':")
	fmt.Println("==============================")

	// Iterate over paths and fix where necessary
    var fixedPaths []cty.Value
    changed := false
	it := val.ElementIterator()
	for it.Next() {
		_, v := it.Element()
		if v.Type() == cty.String {
			originalPath := v.AsString()
			fixedPath    := fixPath(originalPath)
            fixedPaths    = append(fixedPaths, cty.StringVal(fixedPath))
			if originalPath != fixedPath {
				fmt.Printf("  %s -> %s (FIXED)\n", originalPath, fixedPath)
                changed = true
			} else {
				fmt.Printf("  %s (OK)\n", originalPath)
			}
		}
	}
    body.SetAttributeValue("shell_scripts", cty.TupleVal(fixedPaths))
    return changed, nil
}

func openHCL(filename string) ([]byte, map[string]*hcl.Attribute, error) {
    fmt.Println("! Opening:", filename)
    // Read the file
    content, err := os.ReadFile(filename)
    if err != nil {
        return nil, nil, fmt.Errorf("Error reading file: %w", err)
    }

    // Parse the HLC input file
    parser := hclparse.NewParser()
    readFile, diags := parser.ParseHCL(content, filename)
    
    // Validate HCL Syntax
    fmt.Println("")
    fmt.Println("Validating HCL syntax...")
    fmt.Println("========================")
    if diags.HasErrors() {
        return nil, nil, fmt.Errorf("HCL syntax errors:\n%s", diags.Error())
    }
    fmt.Println("✓ Valid HCL syntax")

    // Get all attributes
    attrs, diags := readFile.Body.JustAttributes()
    if diags.HasErrors() {
        return nil, nil, fmt.Errorf(
            "Error getting attributes: %s", diags.Error(),
        )
    }

    return content, attrs, nil
}

func processHCLFile(filename string) error {
    // Open and parse the input file
    content, attrs, open_err := openHCL(filename)
    if nil != open_err {
        return open_err
    }

    // Display variables and values
    printVariables(attrs)

    // Parse with hclwrite - this preserves formatting and allows modification
    writeFile, diags := hclwrite.ParseConfig(
        content, filename, hcl.Pos{Line: 1, Column: 1},
    )
    if diags.HasErrors() {
        return fmt.Errorf(
            "Unable to open HCL file due to syntax errors:\n%s", diags.Error(),
        )
    }

    body := writeFile.Body()
    // Show what we're fixing
    changed, fix_err := fixShellScripts(attrs, body)
    if nil != fix_err {
        return fix_err
    }
    if changed {
        fixedContent := writeFile.Bytes()
        // This does an in-place fix
        write_err := os.WriteFile(filename, fixedContent, 0644)
        if nil != write_err {
            return fmt.Errorf("Error writing file: %w", write_err)
        }
        fmt.Printf("\n✓ Fixed content written to %s\n", "test2.hcl")

        // Display variables and values of the new file
        _, new_attrs, new_open_err := openHCL(filename)
        if nil != new_open_err {
            return new_open_err
        }
        printVariables(new_attrs)
    } else {
        fmt.Println("")
        fmt.Println("No changes applied to: ", filename)
    }

    return nil
}

func main() {
    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}
