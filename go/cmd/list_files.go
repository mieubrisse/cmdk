package cmd

import (
	"os"

	"github.com/mieubrisse/cmdk/internal/listing"
	"github.com/spf13/cobra"
)

var listFilesCmd = &cobra.Command{
	Use:    "list-files",
	Short:  "List files for fzf (internal use)",
	Hidden: true,
	RunE:   runListFiles,
}

var (
	listFlagPWDOnly bool
	listFlagSubdirs bool
)

func init() {
	listFilesCmd.Flags().BoolVarP(&listFlagPWDOnly, "pwd-only", "o", false, "List current directory only")
	listFilesCmd.Flags().BoolVarP(&listFlagSubdirs, "subdirs", "s", false, "List subdirectories recursively")
	rootCmd.AddCommand(listFilesCmd)
}

func runListFiles(command *cobra.Command, args []string) error {
	mode := listing.ModeSystem
	if listFlagPWDOnly {
		mode = listing.ModePWD
	} else if listFlagSubdirs {
		mode = listing.ModeSubdirs
	}

	return listing.ListFiles(os.Stdout, mode)
}
