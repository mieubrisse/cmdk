package cmd

import (
	"github.com/mieubrisse/cmdk/internal/preview"
	"github.com/spf13/cobra"
)

var previewCmd = &cobra.Command{
	Use:    "preview [path]",
	Short:  "Preview a file for fzf (internal use)",
	Hidden: true,
	Args:   cobra.ExactArgs(1),
	RunE:   runPreview,
}

func init() {
	rootCmd.AddCommand(previewCmd)
}

func runPreview(command *cobra.Command, args []string) error {
	return preview.Preview(args[0])
}
