package platform

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"

	"github.com/mieubrisse/stacktrace"
)

// OpenFile opens a file with the system default application.
// On macOS: `open`, on Linux: `xdg-open` (with fallbacks to gio, gnome-open).
// The spawned process runs in the background; this function returns immediately.
func OpenFile(filepath string) error {
	openCmd, err := getOpenCommand()
	if err != nil {
		return err
	}

	cmd := exec.Command(openCmd, filepath)
	if err := cmd.Start(); err != nil {
		return stacktrace.Propagate(err, "failed to open '%s'", filepath)
	}

	// Don't wait — let the app open in the background
	go func() {
		_ = cmd.Wait()
	}()

	return nil
}

// getOpenCommand returns the platform-appropriate command for opening files
// with their default application.
func getOpenCommand() (string, error) {
	switch runtime.GOOS {
	case "darwin":
		return "open", nil
	case "linux":
		for _, cmd := range []string{"xdg-open", "gio", "gnome-open"} {
			if _, err := exec.LookPath(cmd); err == nil {
				return cmd, nil
			}
		}
		return "", stacktrace.NewError("no open command found (tried xdg-open, gio, gnome-open)")
	default:
		fmt.Fprintf(os.Stderr, "Warning: unsupported platform '%s', cannot open files\n", runtime.GOOS)
		return "", stacktrace.NewError("unsupported platform: %s", runtime.GOOS)
	}
}
