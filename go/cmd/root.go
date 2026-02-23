package cmd

import (
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "cmdk",
	Short: "Terminal file navigator — ⌘-K for your shell",
	Long:  "cmdk brings the ⌘-K 'access anything' experience to the terminal.\nUsage: eval \"$(cmdk init)\" in your shell rc file.",
}

var (
	flagPWDOnly bool
	flagSubdirs bool
)

var runCmd = &cobra.Command{
	Use:   "run",
	Short: "Launch the file navigator (called by shell function)",
	RunE:  runCmdk,
}

func init() {
	runCmd.Flags().BoolVarP(&flagPWDOnly, "pwd-only", "o", false, "List current directory contents only (depth 1)")
	runCmd.Flags().BoolVarP(&flagSubdirs, "subdirs", "s", false, "List current directory and recurse into subdirectories")
	rootCmd.AddCommand(runCmd)
}

func Execute() error {
	return rootCmd.Execute()
}

func runCmdk(command *cobra.Command, args []string) error {
	// TODO: will be implemented in subsequent tasks
	return nil
}
