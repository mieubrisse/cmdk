package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/mieubrisse/cmdk/shell"
	"github.com/mieubrisse/stacktrace"
	"github.com/spf13/cobra"
)

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Output shell integration code",
	Long:  "Outputs a shell function definition for cmdk.\nAdd eval \"$(cmdk init)\" to your shell rc file.",
	RunE:  runInit,
}

func init() {
	rootCmd.AddCommand(initCmd)
}

func runInit(command *cobra.Command, args []string) error {
	shellName := detectShell()

	switch shellName {
	case "bash", "zsh":
		fmt.Print(shell.BashInit)
	case "fish":
		fmt.Print(shell.FishInit)
	default:
		return stacktrace.NewError("unsupported shell: %s (supported: bash, zsh, fish)", shellName)
	}

	return nil
}

func detectShell() string {
	shellPath := os.Getenv("SHELL")
	if shellPath == "" {
		return "bash"
	}
	return filepath.Base(shellPath)
}
