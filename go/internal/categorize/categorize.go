package categorize

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/mieubrisse/stacktrace"
)

// Category describes what action to take for a selected file.
type Category int

const (
	CategoryDirectory  Category = iota // cd into this directory
	CategoryTextFile                   // open in $EDITOR
	CategoryOpenTarget                 // open with system open command
	CategoryIgnored                    // do nothing
)

// CategorizedFile pairs a resolved path with its determined category.
type CategorizedFile struct {
	Path     string
	Category Category
}

// CategorizeFiles determines what action to take for each selected path.
// This replicates the categorization logic in cmdk-core.sh (lines 33-67).
func CategorizeFiles(paths []string) ([]CategorizedFile, error) {
	homeDirpath := os.Getenv("HOME")
	results := make([]CategorizedFile, 0, len(paths))

	for _, path := range paths {
		categorized, err := categorizeOne(path, homeDirpath)
		if err != nil {
			return nil, stacktrace.Propagate(err, "failed to categorize '%s'", path)
		}
		results = append(results, categorized)
	}

	return results, nil
}

func categorizeOne(path string, homeDirpath string) (CategorizedFile, error) {
	// Special case: "HOME" literal resolves to the home directory.
	// The shell version does: dirs+=("${HOME}")
	if path == "HOME" {
		return CategorizedFile{Path: homeDirpath, Category: CategoryDirectory}, nil
	}

	// .key files are Keynote presentations whose MIME type is application/zip,
	// so we must check the extension before falling through to MIME detection.
	if strings.ToLower(filepath.Ext(path)) == ".key" {
		return CategorizedFile{Path: path, Category: CategoryOpenTarget}, nil
	}

	mimeType, err := detectMimeType(path)
	if err != nil {
		return CategorizedFile{}, stacktrace.Propagate(err, "failed to detect MIME type for '%s'", path)
	}

	category := categorizeMimeType(mimeType)
	return CategorizedFile{Path: path, Category: category}, nil
}

func categorizeMimeType(mimeType string) Category {
	switch {
	case strings.HasPrefix(mimeType, "text/"):
		return CategoryTextFile
	case mimeType == "application/json":
		return CategoryTextFile
	case mimeType == "inode/directory":
		return CategoryDirectory
	case mimeType == "application/pdf":
		return CategoryOpenTarget
	case mimeType == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return CategoryOpenTarget
	case strings.HasPrefix(mimeType, "image/"):
		return CategoryOpenTarget
	default:
		return CategoryIgnored
	}
}

func detectMimeType(path string) (string, error) {
	cmd := exec.Command("file", "-b", "--mime-type", path)
	output, err := cmd.Output()
	if err != nil {
		return "", stacktrace.Propagate(err, "'file' command failed for '%s'", path)
	}
	return strings.TrimSpace(string(output)), nil
}
