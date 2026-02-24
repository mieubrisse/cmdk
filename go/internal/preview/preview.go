package preview

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/mieubrisse/stacktrace"
)

// Preview generates a preview for the given path and writes it to stdout.
// This replaces preview.sh and is called by the hidden `cmdk preview` subcommand.
func Preview(path string) error {
	// Special case: HOME literal
	if path == "HOME" {
		return runCommand("ls", "--color=always", os.Getenv("HOME"))
	}

	mimeType, err := detectMimeType(path)
	if err != nil {
		// If MIME detection fails, print the error rather than crashing the preview pane
		fmt.Fprintf(os.Stdout, "Cannot preview: %v\n", err)
		return nil
	}

	switch {
	case strings.HasPrefix(mimeType, "text/"), mimeType == "application/json":
		return previewText(path)
	case mimeType == "inode/directory":
		return runCommand("ls", "--color=always", path)
	case strings.HasPrefix(mimeType, "image/"):
		return previewImage(path)
	case mimeType == "application/zip":
		return previewZip(path)
	case mimeType == "application/pdf":
		return previewPDF(path)
	default:
		fmt.Fprintf(os.Stdout, "No preview available (type: %s)\n", mimeType)
		return nil
	}
}

func previewText(path string) error {
	if _, err := exec.LookPath("bat"); err == nil {
		return runCommand("bat", "--style=plain", "--color=always", path)
	}
	fmt.Fprintln(os.Stderr, "Tip: install bat for syntax-highlighted previews (brew install bat)")
	return runCommand("cat", path)
}

func previewImage(path string) error {
	if _, err := exec.LookPath("tiv"); err == nil {
		cmd := exec.Command("tiv", "-w", "100", "-h", "100", path)
		cmd.Stdout = os.Stdout
		// stderr intentionally not connected — matches preview.sh: 2>/dev/null
		return cmd.Run()
	}
	fmt.Fprintln(os.Stdout, "Image preview not available.\nInstall tiv for terminal image previews: brew install tiv")
	return nil
}

func previewZip(path string) error {
	if _, err := exec.LookPath("unzip"); err == nil {
		return runCommand("unzip", "-l", path)
	}
	fmt.Fprintln(os.Stdout, "ZIP preview not available.\nInstall unzip to list archive contents: brew install unzip")
	return nil
}

func previewPDF(path string) error {
	if _, err := exec.LookPath("pdftotext"); err == nil {
		return runCommand("pdftotext", path, "-")
	}
	fmt.Fprintln(os.Stdout, "PDF preview not available.\nInstall poppler for PDF text extraction: brew install poppler")
	return nil
}

func detectMimeType(path string) (string, error) {
	cmd := exec.Command("file", "-b", "--mime-type", path)
	output, err := cmd.Output()
	if err != nil {
		return "", stacktrace.Propagate(err, "'file' command failed for '%s'", path)
	}
	return strings.TrimSpace(string(output)), nil
}

func runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
