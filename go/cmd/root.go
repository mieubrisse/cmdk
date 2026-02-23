package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/mieubrisse/cmdk/internal/categorize"
	"github.com/mieubrisse/cmdk/internal/platform"
	"github.com/mieubrisse/stacktrace"
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
	// Find our own binary path so fzf can call back into cmdk for preview/list-files
	exeFilepath, err := os.Executable()
	if err != nil {
		return stacktrace.Propagate(err, "failed to find cmdk executable path")
	}
	exeFilepath, err = filepath.EvalSymlinks(exeFilepath)
	if err != nil {
		return stacktrace.Propagate(err, "failed to resolve symlinks for executable path")
	}

	// Build flag string for the list-files subcommand
	flagStr := ""
	if flagPWDOnly {
		flagStr = " -o"
	} else if flagSubdirs {
		flagStr = " -s"
	}

	quotedExe := shellQuote(exeFilepath)

	// Launch fzf with our list-files command as the default source
	fzfCmd := exec.Command("fzf",
		"-m",
		"--ansi",
		"--bind=change:top",
		"--scheme=path",
		fmt.Sprintf("--preview=%s preview {}", quotedExe),
	)

	fzfCmd.Env = append(os.Environ(),
		fmt.Sprintf("FZF_DEFAULT_COMMAND=%s list-files%s", quotedExe, flagStr),
	)
	fzfCmd.Stdin = os.Stdin
	fzfCmd.Stderr = os.Stderr

	fzfOutput, err := fzfCmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// Exit code 1 = no match, 130 = user cancelled (Ctrl-C / ESC)
			if exitErr.ExitCode() == 1 || exitErr.ExitCode() == 130 {
				return nil
			}
		}
		return stacktrace.Propagate(err, "fzf failed")
	}

	selections := parseSelections(string(fzfOutput))
	if len(selections) == 0 {
		return nil
	}

	categorized, err := categorize.CategorizeFiles(selections)
	if err != nil {
		return stacktrace.Propagate(err, "failed to categorize selections")
	}

	// Partition selections by category
	var dirPaths []string
	var textFilePaths []string

	for _, cf := range categorized {
		switch cf.Category {
		case categorize.CategoryDirectory:
			dirPaths = append(dirPaths, cf.Path)
		case categorize.CategoryTextFile:
			textFilePaths = append(textFilePaths, cf.Path)
		case categorize.CategoryOpenTarget:
			if err := platform.OpenFile(cf.Path); err != nil {
				fmt.Fprintf(os.Stderr, "Warning: failed to open %s: %v\n", cf.Path, err)
			}
		}
	}

	if len(dirPaths) > 1 {
		return stacktrace.NewError("cannot cd to more than one directory at a time")
	}

	// Write text file paths to a temp file for the shell wrapper to consume
	textFilesFilepath := ""
	if len(textFilePaths) > 0 {
		tmpFile, err := os.CreateTemp("", "cmdk-*.txt")
		if err != nil {
			return stacktrace.Propagate(err, "failed to create temp file")
		}
		for _, tf := range textFilePaths {
			fmt.Fprintln(tmpFile, tf)
		}
		tmpFile.Close()
		textFilesFilepath = tmpFile.Name()
	}

	dirToCD := ""
	if len(dirPaths) == 1 {
		dirToCD = dirPaths[0]
	}

	// Output pipe-delimited result consumed by the shell function
	fmt.Printf("%s|%s", textFilesFilepath, dirToCD)

	return nil
}

var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;]*m`)

func stripANSI(s string) string {
	return ansiRegex.ReplaceAllString(s, "")
}

func parseSelections(output string) []string {
	lines := strings.Split(strings.TrimSpace(output), "\n")
	var selections []string
	for _, line := range lines {
		cleaned := strings.TrimSpace(stripANSI(line))
		if cleaned != "" {
			selections = append(selections, cleaned)
		}
	}
	return selections
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}
