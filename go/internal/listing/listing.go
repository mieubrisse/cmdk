package listing

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/mieubrisse/stacktrace"
)

// Mode controls which files are listed.
type Mode int

const (
	ModeSystem  Mode = iota // System-wide: PWD + HOME + / (default)
	ModePWD                 // Current directory only, depth 1 (-o)
	ModeSubdirs             // Current directory, recursive (-s)
)

// ListFiles writes file listings to the given writer, matching the behavior of list-files.sh.
// The output includes ANSI color codes from fd and should be passed directly to fzf.
func ListFiles(w io.Writer, mode Mode) error {
	homeDirpath := os.Getenv("HOME")
	pwd, err := os.Getwd()
	if err != nil {
		return stacktrace.Propagate(err, "failed to get working directory")
	}

	inHome := pwd == homeDirpath

	// --------------- Current directory listing ---------------
	fdArgs := buildFdBaseArgs()
	fdArgs = append(fdArgs, "--strip-cwd-prefix")

	if mode == ModePWD {
		fdArgs = append(fdArgs, "--max-depth", "1")
	}

	fdArgs = appendExcludes(fdArgs, commonExcludeDirNames)
	if inHome {
		fdArgs = appendExcludes(fdArgs, homeExcludeDirNames)
	}

	fdArgs = append(fdArgs, ".") // search pattern

	if err := runFd(w, fdArgs); err != nil {
		return stacktrace.Propagate(err, "failed to list files in current directory")
	}

	// Add back excluded directories that exist at depth 1 in PWD.
	// These were excluded from fd results but we still want the directory entry itself.
	addBackExcludedDirs(w, pwd, pwd, commonExcludeDirNames)
	if inHome {
		addBackExcludedDirs(w, pwd, pwd, homeExcludeDirNames)
	}

	// --------------- System mode: list beyond current directory ---------------
	if mode == ModeSystem {
		// List HOME if we're not already there
		if !inHome {
			homeFdArgs := buildFdBaseArgs()
			homeFdArgs = appendExcludes(homeFdArgs, homeExcludeDirNames)
			homeFdArgs = appendExcludes(homeFdArgs, commonExcludeDirNames)
			homeFdArgs = append(homeFdArgs, ".", homeDirpath)

			if err := runFd(w, homeFdArgs); err != nil {
				return stacktrace.Propagate(err, "failed to list files in HOME")
			}

			// Add back excluded dirs in HOME (printed as full paths)
			addBackExcludedDirs(w, homeDirpath, pwd, commonExcludeDirNames)
			addBackExcludedDirs(w, homeDirpath, pwd, homeExcludeDirNames)
		}

		// /tmp/ and / as literal entries
		fmt.Fprintln(w, "/tmp/")
		fmt.Fprintln(w, "/")

		// One level of root
		rootFdArgs := buildFdBaseArgs()
		rootFdArgs = append(rootFdArgs, "--exact-depth", "1", ".", "/")
		if err := runFd(w, rootFdArgs); err != nil {
			return stacktrace.Propagate(err, "failed to list root directory")
		}
	}

	// --------------- Omnipresent items ---------------
	fmt.Fprintln(w, "HOME")
	fmt.Fprintln(w, "..")

	return nil
}

func buildFdBaseArgs() []string {
	return []string{"--follow", "--hidden", "--color=always"}
}

func appendExcludes(args []string, excludes []string) []string {
	for _, dirName := range excludes {
		args = append(args, "-E", dirName)
	}
	return args
}

// runFd executes fd with the given arguments, streaming stdout to the writer.
// fd returns exit code 1 when no matches are found, which is not an error for our purposes.
func runFd(w io.Writer, args []string) error {
	cmd := exec.Command("fd", args...)
	cmd.Stdout = w
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 1 {
			return nil
		}
		return stacktrace.Propagate(err, "fd command failed (is fd installed?)")
	}
	return nil
}

// addBackExcludedDirs echoes directory names for excluded dirs that exist at depth 1 in baseDirpath.
// When baseDirpath is the current working directory (pwd), just the name is printed (matches
// --strip-cwd-prefix behavior). Otherwise the full path is printed.
func addBackExcludedDirs(w io.Writer, baseDirpath string, pwd string, excludes []string) {
	for _, dirName := range excludes {
		dirpath := filepath.Join(baseDirpath, dirName)
		info, err := os.Stat(dirpath)
		if err != nil || !info.IsDir() {
			continue
		}

		if baseDirpath == pwd {
			fmt.Fprintln(w, dirName)
		} else {
			fmt.Fprintln(w, dirpath)
		}
	}
}
