cmdk Go Reimplementation Plan
==============================

Overview
--------
Reimplement the existing shell-based cmdk tool as a Go CLI using Cobra. The goal is to maintain feature parity while improving maintainability, testability, and cross-platform support.

Current Implementation Analysis
--------------------------------

### Existing Components

1. **cmdk-core.sh** (95 lines)
   - Launches fzf with file listings from list-files.sh
   - Uses preview.sh for file previews
   - Categorizes selected files by MIME type
   - Returns pipe-delimited results to parent shell

2. **list-files.sh** (145 lines)
   - Three modes: system-wide, current directory only (-o), subdirectories (-s)
   - Excludes common project directories (node_modules, .git, build artifacts, etc.)
   - Excludes HOME-specific directories (Library, Applications, etc.)
   - Uses fd command with ANSI color output
   - Adds back excluded directories at depth 1

3. **preview.sh** (38 lines)
   - Text files: bat with syntax highlighting
   - Directories: ls with colors
   - Images: tiv (terminal image viewer)
   - PDFs: pdftotext
   - Zip files: unzip -l

4. **cmdk.sh / cmdk.fish** (52 / 42 lines)
   - Shell integration wrapper
   - Parses pipe-delimited results
   - cd to directories in parent shell
   - Opens text files in $EDITOR in parent shell
   - Handles bash/zsh word splitting differences

### Key External Dependencies
- **fzf** - Fuzzy finder (core UI component)
- **fd** - Fast file finder (file listing)
- **bat** - Syntax-highlighted file viewer (optional, for previews)
- **tiv** - Terminal image viewer (optional, for image previews)
- **poppler** (pdftotext) - PDF previewer (optional, for PDF previews)

### Key Challenges

1. **Shell Integration**
   - Cannot cd in parent shell from Go binary
   - Cannot open editor in parent shell from Go binary
   - **Solution**: Maintain shell wrapper pattern but simplify implementation

2. **External Dependencies**
   - Current implementation relies on fzf, fd, bat, tiv, pdftotext
   - **Solution**: Keep fzf as core dependency, make others optional with graceful degradation

3. **Platform Support**
   - Shell scripts work on macOS/Linux
   - Go can support Windows with conditional compilation
   - **Solution**: Use conditional compilation for platform-specific features (e.g., 'open' command)

Project Structure
-----------------

```
cmdk/
├── main.go                    # Entry point, Cobra setup
├── go.mod
├── go.sum
├── cmd/
│   └── root.go               # Root command with flags (-o, -s)
├── internal/
│   ├── config/
│   │   ├── config.go         # Configuration management
│   │   └── excludes.go       # Exclude directory lists
│   ├── files/
│   │   ├── lister.go         # File listing logic (replaces list-files.sh)
│   │   ├── categorizer.go    # File categorization by MIME type
│   │   └── mime.go           # MIME type detection utilities
│   ├── preview/
│   │   ├── previewer.go      # Preview logic (replaces preview.sh)
│   │   ├── text.go           # Text file preview
│   │   ├── image.go          # Image preview
│   │   ├── pdf.go            # PDF preview
│   │   └── directory.go      # Directory listing preview
│   ├── fzf/
│   │   ├── launcher.go       # fzf integration (replaces cmdk-core.sh fzf launch)
│   │   └── options.go        # fzf command-line options builder
│   ├── output/
│   │   ├── formatter.go      # Output formatting for shell consumption
│   │   └── result.go         # Result types
│   └── shell/
│       ├── detector.go       # Shell detection (bash/zsh/fish)
│       └── integration.go    # Shell integration helpers
├── scripts/
│   ├── cmdk.sh              # Shell wrapper (simplified version)
│   ├── cmdk.fish            # Fish wrapper (simplified version)
│   └── install.sh           # Installation script
├── testdata/                # Test fixtures
│   ├── files/
│   ├── directories/
│   └── expected/
└── README.md
```

Core Packages and Responsibilities
-----------------------------------

### 1. `cmd/root.go` - Command-line Interface
**Responsibilities:**
- Define Cobra root command
- Parse flags: `-o` (current directory only), `-s` (subdirectories)
- Orchestrate workflow: list → preview → select → categorize → output
- Handle errors and exit codes

**Key Functions:**
- `Execute()` - Main entry point
- `runCmdk(mode Mode) error` - Core execution logic

### 2. `internal/config` - Configuration Management
**Responsibilities:**
- Define exclude lists (common project dirs, HOME-specific dirs)
- Load configuration from environment or config file (future)
- Provide mode constants

**Key Types:**
```go
type Mode int

const (
    ModeSystem   Mode = iota  // System-wide search
    ModePWD                   // Current directory only (-o)
    ModeSubdirs               // Subdirectories (-s)
)

type Config struct {
    CommonExcludes []string
    HomeExcludes   []string
    Mode           Mode
    HomeDir        string
    PWD            string
}
```

### 3. `internal/files` - File Listing and Categorization
**Responsibilities:**
- Generate file listings using fd
- Exclude unwanted directories
- Re-add excluded directories at depth 1
- Categorize files by MIME type
- Handle special cases (HOME, .., etc.)

**Key Types:**
```go
type FileList struct {
    Paths []string
}

type FileCategory int

const (
    CategoryDirectory FileCategory = iota
    CategoryTextFile
    CategoryOpenTarget  // PDFs, images, .key files, etc.
)

type CategorizedFile struct {
    Path     string
    Category FileCategory
}
```

**Key Functions:**
- `ListFiles(cfg *config.Config) (*FileList, error)` - Generate file listing
- `CategorizeFiles(paths []string) ([]CategorizedFile, error)` - Categorize by MIME
- `DetectMimeType(path string) (string, error)` - MIME type detection

### 4. `internal/preview` - File Previewing
**Responsibilities:**
- Generate previews for different file types
- Fall back gracefully if preview tools unavailable
- Handle special cases (HOME, directories, etc.)

**Key Functions:**
- `Preview(path string) (string, error)` - Main preview dispatcher
- `previewText(path string) (string, error)` - Text file preview (bat or cat)
- `previewImage(path string) (string, error)` - Image preview (tiv or placeholder)
- `previewPDF(path string) (string, error)` - PDF preview (pdftotext or placeholder)
- `previewDirectory(path string) (string, error)` - Directory listing (ls)

### 5. `internal/fzf` - fzf Integration
**Responsibilities:**
- Launch fzf with appropriate options
- Pipe file listings to fzf
- Configure preview command
- Capture user selections

**Key Types:**
```go
type Options struct {
    Multi      bool     // -m flag
    ANSI       bool     // --ansi flag
    Scheme     string   // --scheme=path
    Preview    string   // --preview command
    BindChange bool     // --bind='change:top'
}

type Selection struct {
    Paths []string
    Cancelled bool
}
```

**Key Functions:**
- `Launch(input *files.FileList, opts Options) (*Selection, error)` - Launch fzf
- `BuildPreviewCommand() string` - Build preview command for current binary

### 6. `internal/output` - Output Formatting
**Responsibilities:**
- Format results for shell consumption
- Maintain backward compatibility with existing shell wrappers
- Handle edge cases (multiple directories, etc.)

**Key Types:**
```go
type Result struct {
    TextFilesPath string  // Path to temp file with text file list
    DirectoryPath string  // Directory to cd to (single only)
    Error         error   // Any errors encountered
}
```

**Key Functions:**
- `FormatResult(categorized []files.CategorizedFile) (*Result, error)` - Format results
- `WriteTempFileList(paths []string) (string, error)` - Write temp file with paths
- `ValidateDirectorySelection(dirs []string) error` - Ensure max 1 directory selected

### 7. `internal/shell` - Shell Integration
**Responsibilities:**
- Detect current shell (bash/zsh/fish)
- Provide shell-specific helpers (future use)

**Key Functions:**
- `DetectShell() string` - Detect current shell from $SHELL env var
- Future: shell-specific escape sequences, word splitting, etc.

Critical Implementation Details
--------------------------------

### fzf Integration Architecture

This is the most complex component with the highest risk. Complete specification follows:

#### Process Management

**Main Execution Flow:**
```go
func Launch(ctx context.Context, input *files.FileList, opts Options) (*Selection, error) {
    // Create context with timeout (default: 5 minutes, configurable via CMDK_FZF_TIMEOUT)
    timeout := 5 * time.Minute
    if envTimeout := os.Getenv("CMDK_FZF_TIMEOUT"); envTimeout != "" {
        timeout, _ = time.ParseDuration(envTimeout)
    }
    ctx, cancel := context.WithTimeout(ctx, timeout)
    defer cancel()

    // Build fzf command with context (enables cancellation)
    exePath, err := os.Executable()
    if err != nil {
        return nil, stacktrace.Propagate(err, "failed to find cmdk executable path")
    }

    previewCmd := fmt.Sprintf("%s preview {}", exePath)
    fzfCmd := exec.CommandContext(ctx,
        "fzf",
        "-m",                           // Multi-select
        "--ansi",                       // Parse ANSI colors
        "--scheme=path",                // Path-based scoring
        "--bind=change:top",            // Reset to top on input change
        "--preview-window=right:60%:wrap",
        fmt.Sprintf("--preview=%s", previewCmd),
    )

    // Pipe file listings to fzf stdin (streaming, not buffered)
    stdin, err := fzfCmd.StdinPipe()
    if err != nil {
        return nil, stacktrace.Propagate(err, "failed to create stdin pipe for fzf")
    }

    // Capture stdout for selections
    stdout, err := fzfCmd.StdoutPipe()
    if err != nil {
        return nil, stacktrace.Propagate(err, "failed to create stdout pipe for fzf")
    }

    // Start fzf
    if err := fzfCmd.Start(); err != nil {
        return nil, stacktrace.Propagate(err, "failed to start fzf - is fzf installed?")
    }

    // Stream file listings to fzf (non-blocking)
    go func() {
        for _, path := range input.Paths {
            fmt.Fprintln(stdin, path)
        }
        stdin.Close()
    }()

    // Read selections
    selections, err := readSelections(stdout)

    // Wait for fzf to complete
    if err := fzfCmd.Wait(); err != nil {
        if exitErr, ok := err.(*exec.ExitError); ok {
            if exitErr.ExitCode() == 130 {
                // User cancelled (Ctrl-C or ESC) - not an error
                return &Selection{Cancelled: true}, nil
            }
        }
        return nil, stacktrace.Propagate(err, "fzf exited with error")
    }

    return &Selection{Paths: selections, Cancelled: false}, nil
}
```

**Signal Handling:**
```go
// In main.go, set up signal handler
func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Handle SIGINT and SIGTERM
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
    go func() {
        <-sigChan
        cancel() // Cancel context, which kills fzf subprocess
        os.Exit(130) // Exit with same code as Ctrl-C
    }()

    // Run main command with context
    if err := cmd.ExecuteContext(ctx); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
```

#### Preview Command Specification

**Preview Subcommand:**
```go
// In cmd/preview.go
var previewCmd = &cobra.Command{
    Use:    "preview <path>",
    Short:  "Preview a file (internal use by fzf)",
    Hidden: true,  // Don't show in --help
    Args:   cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        path := args[0]

        // Set timeout for preview generation (prevent hanging UI)
        ctx, cancel := context.WithTimeout(cmd.Context(), 500*time.Millisecond)
        defer cancel()

        output, err := preview.Preview(ctx, path)
        if err != nil {
            // Don't fail - show error in preview pane
            fmt.Fprintf(os.Stdout, "Error previewing %s:\n%v", path, err)
            return nil
        }

        // Limit output size (fzf performance)
        lines := strings.Split(output, "\n")
        if len(lines) > 10000 {
            lines = lines[:10000]
            lines = append(lines, "", "... (output truncated, >10k lines) ...")
        }

        fmt.Print(strings.Join(lines, "\n"))
        return nil
    },
}
```

**Preview Implementation with Timeout:**
```go
// In internal/preview/previewer.go
func Preview(ctx context.Context, path string) (string, error) {
    // Handle special cases first
    if path == "HOME" {
        return listDirectory(ctx, os.Getenv("HOME"))
    }
    if path == ".." {
        parent := filepath.Dir(os.Getenv("PWD"))
        return listDirectory(ctx, parent)
    }

    // Detect type and preview
    mimeType, err := DetectMimeType(path)
    if err != nil {
        return "", stacktrace.Propagate(err, "failed to detect MIME type for %s", path)
    }

    switch {
    case strings.HasPrefix(mimeType, "text/"), mimeType == "application/json":
        return previewText(ctx, path)
    case mimeType == "inode/directory":
        return listDirectory(ctx, path)
    case strings.HasPrefix(mimeType, "image/"):
        return previewImage(ctx, path)
    case mimeType == "application/pdf":
        return previewPDF(ctx, path)
    case strings.HasSuffix(path, ".key"): // Keynote files
        return "Keynote presentation: " + path, nil
    default:
        return fmt.Sprintf("No preview available for %s (type: %s)", path, mimeType), nil
    }
}

func previewText(ctx context.Context, path string) (string, error) {
    // Check if bat is available (cached check)
    if hasBat() {
        return executeCommand(ctx, "bat", "--style=plain", "--color=always", path)
    }
    // Fallback to cat
    return executeCommand(ctx, "cat", path)
}
```

**fzf Exit Code Handling:**
- Exit code 0: Normal exit with selection
- Exit code 1: Error occurred
- Exit code 130: User cancelled (Ctrl-C or ESC) - **not an error**, return `Selection{Cancelled: true}`

### Error Handling Strategy

All error handling will follow these patterns:

#### Package Boundary Pattern
```go
// At package boundaries, wrap with context
func ListFiles(cfg *config.Config) (*FileList, error) {
    result, err := executeFd(cfg)
    if err != nil {
        return nil, stacktrace.Propagate(err, "failed to list files in mode %v", cfg.Mode)
    }
    return result, nil
}
```

#### External Command Error Pattern
```go
func executeFd(cfg *config.Config) (*FileList, error) {
    cmd := exec.Command("fd", buildArgs(cfg)...)
    output, err := cmd.CombinedOutput()

    if err != nil {
        if exitErr, ok := err.(*exec.ExitError); ok {
            // External command failed - provide user-friendly message
            return nil, stacktrace.NewError(
                "fd command failed (exit %d): %s\nIs fd installed? Try: brew install fd",
                exitErr.ExitCode(),
                string(output),
            )
        }
        // Other error (e.g., command not found)
        return nil, stacktrace.Propagate(err, "failed to execute fd command")
    }

    return parseOutput(output), nil
}
```

#### User-Facing vs Debug Errors
```go
// In main.go
func main() {
    if err := cmd.Execute(); err != nil {
        // User-facing: clean error message
        if verbose := os.Getenv("CMDK_VERBOSE"); verbose != "" {
            // Debug mode: show stack trace
            fmt.Fprintf(os.Stderr, "Error: %+v\n", err)
        } else {
            // Normal mode: clean message
            fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        }
        os.Exit(1)
    }
}
```

**Guidelines:**
- Wrap errors at package boundaries with `stacktrace.Propagate()`
- Create new errors for user-facing issues with `stacktrace.NewError()`
- Provide actionable error messages ("is fd installed?" vs "command failed")
- Distinguish between user errors and system errors
- Use `CMDK_VERBOSE=1` to enable stack trace output
- Never show stack traces in normal operation

### Concurrency and Resource Management

#### Streaming Architecture
```go
// File listings are streamed, not buffered
func listFilesStreaming(cfg *config.Config) (io.Reader, error) {
    cmd := exec.Command("fd", buildArgs(cfg)...)

    stdout, err := cmd.StdoutPipe()
    if err != nil {
        return nil, stacktrace.Propagate(err, "failed to create stdout pipe")
    }

    if err := cmd.Start(); err != nil {
        return nil, stacktrace.Propagate(err, "failed to start fd")
    }

    // Return reader that will stream results
    // Caller is responsible for reading and cleanup
    return stdout, nil
}
```

#### Cleanup Registry Pattern
```go
// In internal/cleanup/registry.go
type Registry struct {
    mu       sync.Mutex
    cleanups []func()
}

var global = &Registry{}

func Register(fn func()) {
    global.mu.Lock()
    defer global.mu.Unlock()
    global.cleanups = append(global.cleanups, fn)
}

func Cleanup() {
    global.mu.Lock()
    defer global.mu.Unlock()
    for i := len(global.cleanups) - 1; i >= 0; i-- {
        global.cleanups[i]()
    }
}

// In main.go
func main() {
    defer cleanup.Cleanup()

    // ... rest of main
}
```

#### Preview Command Concurrency Safety
- Preview commands MUST be stateless
- All preview functions receive context for timeout
- No shared mutable state between preview invocations
- Tool availability checks cached in memory (read-only after first check)

#### Signal Handling
```go
// In main.go
func setupSignalHandling(ctx context.Context, cancel context.CancelFunc) {
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

    go func() {
        <-sigChan
        // Trigger cleanup
        cleanup.Cleanup()
        // Cancel context (kills child processes)
        cancel()
        // Exit with 130 (standard Ctrl-C exit code)
        os.Exit(130)
    }()
}
```

### Temporary File Management

Complete lifecycle specification:

#### Creation
```go
func WriteTempFileList(paths []string) (string, error) {
    tmpFile, err := os.CreateTemp(os.TempDir(), "cmdk-*.txt")
    if err != nil {
        return "", stacktrace.Propagate(err, "failed to create temp file")
    }

    // Set restrictive permissions (owner read/write only)
    if err := tmpFile.Chmod(0600); err != nil {
        tmpFile.Close()
        os.Remove(tmpFile.Name())
        return "", stacktrace.Propagate(err, "failed to set temp file permissions")
    }

    // Write paths (newline-separated)
    for _, path := range paths {
        if _, err := fmt.Fprintln(tmpFile, path); err != nil {
            tmpFile.Close()
            os.Remove(tmpFile.Name())
            return "", stacktrace.Propagate(err, "failed to write to temp file")
        }
    }

    // Register cleanup (in case shell wrapper fails)
    tmpPath := tmpFile.Name()
    cleanup.Register(func() {
        os.Remove(tmpPath)
    })

    if err := tmpFile.Close(); err != nil {
        os.Remove(tmpPath)
        return "", stacktrace.Propagate(err, "failed to close temp file")
    }

    return tmpPath, nil
}
```

#### Lifecycle
1. **Go binary creates temp file** using `os.CreateTemp()`
2. **Go binary writes paths** (newline-separated)
3. **Go binary prints path to stdout** (pipe-delimited format)
4. **Shell wrapper reads temp file** to get list of text files
5. **Shell wrapper passes paths to $EDITOR**
6. **Shell wrapper deletes temp file** via trap on EXIT

#### Shell Wrapper Cleanup
```bash
# In scripts/cmdk.sh
function cmdk() {
    # ... setup ...

    result=$(cmdk-go "$@")
    IFS="|" read -r text_files_path directory_path <<< "$result"

    # Cleanup function
    cleanup_temp_file() {
        if [ -n "$text_files_path" ] && [ -f "$text_files_path" ]; then
            rm -f "$text_files_path"
        fi
    }
    trap cleanup_temp_file EXIT

    # ... rest of wrapper logic ...
}
```

#### Startup Cleanup
```go
// In cmd/root.go
func init() {
    // Clean up stale temp files at startup (older than 1 hour)
    go cleanupStaleTemp files()
}

func cleanupStaleTempFiles() {
    tmpDir := os.TempDir()
    entries, err := os.ReadDir(tmpDir)
    if err != nil {
        return // Silent failure, non-critical
    }

    cutoff := time.Now().Add(-1 * time.Hour)
    for _, entry := range entries {
        if !strings.HasPrefix(entry.Name(), "cmdk-") {
            continue
        }
        if !strings.HasSuffix(entry.Name(), ".txt") {
            continue
        }

        info, err := entry.Info()
        if err != nil {
            continue
        }

        if info.ModTime().Before(cutoff) {
            os.Remove(filepath.Join(tmpDir, entry.Name()))
        }
    }
}
```

#### Manual Cleanup Command
```go
// Add hidden cleanup subcommand
var cleanupCmd = &cobra.Command{
    Use:    "cleanup",
    Short:  "Remove old cmdk temporary files",
    Hidden: false,  // User-visible for manual cleanup
    RunE: func(cmd *cobra.Command, args []string) error {
        count := cleanupAllTempFiles()
        fmt.Printf("Removed %d temporary file(s)\n", count)
        return nil
    },
}
```

### "Open" Command Platform Handling

Complete specification for opening files with system default applications:

#### Platform Detection
```go
// In internal/opener/opener.go
func getOpenCommand() (string, error) {
    switch runtime.GOOS {
    case "darwin":
        return "open", nil
    case "linux":
        // Try xdg-open first, fallback to alternatives
        if _, err := exec.LookPath("xdg-open"); err == nil {
            return "xdg-open", nil
        }
        // Fallback to common alternatives
        for _, cmd := range []string{"gio", "gnome-open", "kde-open"} {
            if _, err := exec.LookPath(cmd); err == nil {
                return cmd, nil
            }
        }
        return "", stacktrace.NewError("no suitable open command found (tried: xdg-open, gio, gnome-open, kde-open)")
    default:
        return "", stacktrace.NewError("unsupported platform: %s", runtime.GOOS)
    }
}
```

#### Execution Timing
- `open` commands execute **before** returning results to shell
- Executed **synchronously** (wait for command to start, but not complete)
- Errors are **non-fatal** - display warning but continue

#### Implementation
```go
func OpenFiles(paths []string) error {
    openCmd, err := getOpenCommand()
    if err != nil {
        return err
    }

    var errors []string
    for _, path := range paths {
        cmd := exec.Command(openCmd, path)

        // Start command but don't wait (file opens in background)
        if err := cmd.Start(); err != nil {
            errors = append(errors, fmt.Sprintf("  - %s: %v", path, err))
            continue
        }

        // Optionally wait a moment to detect immediate failures
        go func() {
            if err := cmd.Wait(); err != nil {
                // Log but don't block
                if os.Getenv("CMDK_DEBUG") != "" {
                    fmt.Fprintf(os.Stderr, "Warning: %s exited with error: %v\n", openCmd, err)
                }
            }
        }()
    }

    if len(errors) > 0 {
        fmt.Fprintf(os.Stderr, "Warning: failed to open some files:\n%s\n", strings.Join(errors, "\n"))
    }

    return nil
}
```

#### File Exclusion
Files passed to `open` are **NOT** included in the text files list returned to shell.

#### Disable Flag
```go
// Add --no-open flag
var rootCmd = &cobra.Command{
    // ...
}

var noOpen bool

func init() {
    rootCmd.Flags().BoolVar(&noOpen, "no-open", false, "Don't open PDFs/images/media files, return all selections as paths")
}
```

Key Data Structures
-------------------

### File Listing Flow
```
Config → ListFiles → FileList → fzf.Launch → Selection → CategorizeFiles →
CategorizedFile[] → FormatResult → Result → Output (pipe-delimited)
```

### Configuration Structure
```go
type Config struct {
    Mode           Mode
    HomeDir        string
    PWD            string
    CommonExcludes []string
    HomeExcludes   []string
    FdCommand      string        // Path to fd binary (default: "fd")
    BatCommand     string        // Path to bat binary (optional)
    TivCommand     string        // Path to tiv binary (optional)
    PdftotextCmd   string        // Path to pdftotext binary (optional)
}
```

### Result Communication
```go
// Pipe-delimited output format (backward compatible)
// Format: "{text_files_temp_path}|{directory_to_cd}"
// Example: "/tmp/cmdk-12345|/Users/alice/Documents"
// Example: "/tmp/cmdk-12345|"
// Example: "|/Users/alice/Documents"
```

### External Command Abstraction

All external commands are abstracted behind interfaces for testability and consistency:

#### Interface Definition
```go
// In internal/exec/command.go
type ExternalCommand interface {
    Name() string
    IsAvailable() bool
    Execute(ctx context.Context, args ...string) (stdout, stderr string, err error)
}

type BaseCommand struct {
    name      string
    available *bool  // Cached availability check
    mu        sync.RWMutex
}

func (b *BaseCommand) Name() string {
    return b.name
}

func (b *BaseCommand) IsAvailable() bool {
    b.mu.RLock()
    if b.available != nil {
        defer b.mu.RUnlock()
        return *b.available
    }
    b.mu.RUnlock()

    b.mu.Lock()
    defer b.mu.Unlock()

    // Check if command exists
    _, err := exec.LookPath(b.name)
    available := err == nil
    b.available = &available
    return available
}

func (b *BaseCommand) Execute(ctx context.Context, args ...string) (string, string, error) {
    cmd := exec.CommandContext(ctx, b.name, args...)

    var stdout, stderr bytes.Buffer
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr

    if err := cmd.Run(); err != nil {
        return stdout.String(), stderr.String(), err
    }

    return stdout.String(), stderr.String(), nil
}
```

#### Concrete Implementations
```go
// Standard commands
var (
    FdCommand     = &BaseCommand{name: "fd"}
    FzfCommand    = &BaseCommand{name: "fzf"}
    BatCommand    = &BaseCommand{name: "bat"}
    TivCommand    = &BaseCommand{name: "tiv"}
    PdftotextCmd  = &BaseCommand{name: "pdftotext"}
    FileCommand   = &BaseCommand{name: "file"}
)

// For testing: mock implementation
type MockCommand struct {
    name      string
    available bool
    stdout    string
    stderr    string
    err       error
}

func (m *MockCommand) Name() string { return m.name }
func (m *MockCommand) IsAvailable() bool { return m.available }
func (m *MockCommand) Execute(ctx context.Context, args ...string) (string, string, error) {
    return m.stdout, m.stderr, m.err
}
```

#### Usage Pattern
```go
// In internal/files/lister.go
func ListFiles(cfg *config.Config, cmd exec.ExternalCommand) (*FileList, error) {
    if !cmd.IsAvailable() {
        return nil, stacktrace.NewError("%s is not installed or not in PATH", cmd.Name())
    }

    args := buildFdArgs(cfg)
    stdout, stderr, err := cmd.Execute(context.Background(), args...)

    if err != nil {
        return nil, stacktrace.Propagate(err,
            "fd command failed\nStdout: %s\nStderr: %s\nHint: Try 'brew install fd'",
            stdout, stderr)
    }

    return parseFileList(stdout), nil
}
```

#### Testing with Mocks
```go
// In internal/files/lister_test.go
func TestListFiles(t *testing.T) {
    tests := []struct {
        name     string
        mockOut  string
        mockErr  error
        wantErr  bool
        wantLen  int
    }{
        {
            name:    "successful listing",
            mockOut: "file1.txt\nfile2.go\ndir1/\n",
            wantLen: 3,
        },
        {
            name:    "fd fails",
            mockErr: errors.New("fd error"),
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockCmd := &MockCommand{
                name:      "fd",
                available: tt.mockErr == nil,
                stdout:    tt.mockOut,
                err:       tt.mockErr,
            }

            cfg := &config.Config{Mode: config.ModeSystem}
            result, err := ListFiles(cfg, mockCmd)

            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Len(t, result.Paths, tt.wantLen)
            }
        })
    }
}
```

Implementation Approach
-----------------------

### Phase 1: Project Setup and Core Infrastructure
**Goals:**
- Set up Go module with Cobra
- Implement configuration management
- Create basic project structure
- Add error handling with stacktrace library

**Deliverables:**
- `go.mod` with dependencies (cobra, stacktrace, mimetype, slog)
- `internal/config` package with Config struct and constants
- `internal/exec` package with command abstraction
- `internal/cleanup` package with cleanup registry
- `main.go` with basic Cobra setup, signal handling, cleanup
- `cmd/root.go` with flag parsing (-o, -s, --no-open, --log-level)
- `cmd/health.go` with health check command
- `cmd/cleanup.go` with cleanup command

**Checklist:**
- [ ] `go.mod` created with all dependencies
- [ ] `main.go` created with version info embedded via ldflags
- [ ] Signal handling (SIGINT, SIGTERM) properly configured
- [ ] Cleanup registry implemented and registered in main
- [ ] `cmd/root.go` created with all flags
- [ ] `internal/config` package with Config struct
- [ ] `Config.Validate()` implemented and tested
- [ ] `internal/exec` package with ExternalCommand interface
- [ ] BaseCommand and MockCommand implementations
- [ ] Health check command implemented
- [ ] Cleanup command implemented
- [ ] Unit tests for config package (>90% coverage)
- [ ] Unit tests for exec package
- [ ] README updated with build instructions
- [ ] Can successfully run: `go build && ./cmdk --help`
- [ ] Can successfully run: `./cmdk health`

**Time Estimate:** 4-5 hours (increased from 2-3 due to additional infrastructure)

### Phase 2: File Listing
**Goals:**
- Implement fd-based file listing
- Handle exclude directories
- Re-add excluded directories at depth 1
- Support three modes (system, pwd, subdirs)

**Deliverables:**
- `internal/files/lister.go` with ListFiles function
- `internal/files/excludes.go` with exclude list constants
- Unit tests for exclude logic
- Integration tests with real filesystem

**Checklist:**
- [ ] `ListFiles(cfg, cmd)` implemented with ExternalCommand interface
- [ ] fd argument building for all three modes
- [ ] Exclude directory logic implemented
- [ ] Re-add excluded directories at depth 1
- [ ] HOME-specific excludes when PWD == HOME
- [ ] Special entries added (HOME, .., /, /tmp/)
- [ ] ANSI color code preservation in output
- [ ] Streaming output support (io.Reader)
- [ ] Unit tests with mocked fd command (15+ tests)
- [ ] Table-driven tests for all modes
- [ ] Integration tests with real fd (8 tests)
- [ ] Test with large directory (>1000 files)
- [ ] Error handling for fd not found
- [ ] Error handling for fd execution failure
- [ ] Documentation and code comments

**Time Estimate:** 4-6 hours

**Key Implementation Details:**
- Use `ExternalCommand` interface to run fd
- Parse fd output preserving ANSI color codes
- Handle HOME-specific excludes when PWD == HOME
- Add special entries (HOME, .., /, /tmp/)
- Stream output rather than buffering entirely

### Phase 3: File Categorization
**Goals:**
- Detect MIME types using file command
- Categorize into directories, text files, open targets
- Handle special cases (.key files, application/json, etc.)

**Deliverables:**
- `internal/files/categorizer.go` with CategorizeFiles function
- `internal/files/mime.go` with MIME detection
- Unit tests with various file types

**Time Estimate:** 3-4 hours

**Key Implementation Details:**
- Use `file -b --mime-type` command
- Map MIME types to categories
- Special handling for .key extension (Keynote files)
- Handle HOME special case

### Phase 4: Preview System
**Goals:**
- Implement preview for different file types
- Gracefully degrade if optional tools missing
- Create preview command that Go binary can invoke

**Deliverables:**
- `internal/preview/previewer.go` with main Preview function
- Type-specific preview implementations
- Fallback logic for missing tools
- Preview subcommand (hidden) for fzf integration

**Time Estimate:** 4-5 hours

**Key Implementation Details:**
- Add hidden `preview` subcommand to Cobra app
- Check for tool availability (bat, tiv, pdftotext)
- Fallback to cat/less for text if bat unavailable
- Fallback to placeholder message for images/PDFs if tools unavailable
- Use ls for directory previews

### Phase 5: fzf Integration
**Goals:**
- Launch fzf with file listings
- Configure fzf options (multi-select, ANSI, scheme, preview)
- Capture user selections
- Handle cancellation (Ctrl-C, ESC)

**Deliverables:**
- `internal/fzf/launcher.go` with Launch function
- `internal/fzf/options.go` with option builders
- Integration tests (may require manual testing)

**Time Estimate:** 3-4 hours

**Key Implementation Details:**
- Set FZF_DEFAULT_COMMAND environment variable
- Build preview command pointing to `cmdk preview`
- Pipe file listings to fzf stdin
- Parse fzf stdout for selections
- Check exit code for cancellation

### Phase 6: Output Formatting and Result Handling
**Goals:**
- Format results for shell consumption
- Create temp file for text file lists
- Validate directory selections (max 1)
- Execute 'open' command for open targets

**Deliverables:**
- `internal/output/formatter.go` with FormatResult function
- `internal/output/result.go` with Result types
- Unit tests for formatting logic

**Time Estimate:** 2-3 hours

**Key Implementation Details:**
- Create temp file in /tmp for text file list
- Print pipe-delimited output to stdout
- Execute `open` command for PDFs, images, .key files
- Return error if multiple directories selected

### Phase 7: Shell Integration Wrappers
**Goals:**
- Simplify existing shell wrappers
- Maintain backward compatibility
- Support bash, zsh, fish

**Deliverables:**
- Updated `scripts/cmdk.sh` (simplified)
- Updated `scripts/cmdk.fish` (simplified)
- Installation script

**Time Estimate:** 2-3 hours

**Key Implementation Details:**
- Shell wrappers call Go binary instead of cmdk-core.sh
- Parse pipe-delimited output
- cd to directory if present
- Open text files in $EDITOR if present
- No more word-splitting complexity (handled in Go)

### Phase 8: Testing and Documentation
**Goals:**
- Comprehensive unit tests
- Integration tests
- Update README with installation instructions
- Migration guide from shell to Go

**Deliverables:**
- Test coverage >80%
- Updated README.md
- MIGRATION.md guide

**Time Estimate:** 4-6 hours

Testing Strategy
----------------

### Test Pyramid

```
                    /\
                   /  \          Manual Testing
                  /    \         (30 test cases: 3 shells × 10 scenarios)
                 /------\
                /        \       Integration Tests
               /          \      (~20 tests: real fd, mocked fzf)
              /------------\
             /              \    Unit Tests
            /                \   (~60 tests across all packages, >80% coverage)
           /------------------\
```

### Unit Tests (~60 tests, >80% coverage)

#### 1. config package (8-10 tests)
```go
// config_test.go
TestNewConfig()                  // Config initialization
TestConfigValidate()             // Validation logic
TestConfigValidate_MissingHome() // Error cases
TestConfigValidate_InvalidMode() // Invalid mode
TestExcludeListGeneration()      // Common excludes
TestHomeExcludeListGeneration()  // HOME-specific excludes
TestModeFromFlags()              // Flag parsing
```

#### 2. files package (15-20 tests)
```go
// lister_test.go
TestListFiles_SystemMode()       // System-wide listing
TestListFiles_PWDMode()          // Current directory only
TestListFiles_SubdirsMode()      // Subdirectories
TestListFiles_WithExcludes()     // Exclude logic
TestListFiles_FdNotAvailable()   // Error handling
TestBuildFdArgs()                // Argument construction
TestParseFdOutput()              // ANSI color handling

// categorizer_test.go
TestCategorizeFiles_TextFiles()  // Text file detection
TestCategorizeFiles_Directories() // Directory detection
TestCategorizeFiles_Images()     // Image detection
TestCategorizeFiles_PDFs()       // PDF detection
TestCategorizeFiles_KeynoteFiles() // .key extension
TestCategorizeFiles_Mixed()      // Mixed file types
TestCategorizeFiles_SpecialCases() // HOME, .., etc.

// mime_test.go
TestDetectMimeType_Library()     // Go library detection
TestDetectMimeType_Fallback()    // file command fallback
TestDetectMimeType_Cache()       // Caching behavior
```

#### 3. preview package (12-15 tests)
```go
// previewer_test.go
TestPreview_TextFile()           // Text preview
TestPreview_Directory()          // Directory listing
TestPreview_Image()              // Image preview
TestPreview_PDF()                // PDF preview
TestPreview_SpecialCases()       // HOME, ..
TestPreview_Timeout()            // Timeout handling
TestPreview_ToolNotAvailable()   // Fallback behavior

// text_test.go
TestPreviewText_WithBat()        // bat available
TestPreviewText_FallbackToCat()  // bat unavailable

// image_test.go
TestPreviewImage_WithTiv()       // tiv available
TestPreviewImage_Fallback()      // tiv unavailable
```

#### 4. fzf package (10-12 tests)
```go
// launcher_test.go
TestLaunch_WithMock()            // Mock fzf interface
TestLaunch_Cancelled()           // User cancellation (exit 130)
TestLaunch_Error()               // fzf error
TestLaunch_Timeout()             // Context timeout
TestBuildOptions()               // Option construction
TestBuildPreviewCommand()        // Preview command with executable path
TestReadSelections()             // Selection parsing

// options_test.go
TestOptions_Default()            // Default options
TestOptions_Custom()             // Custom options
```

#### 5. output package (8-10 tests)
```go
// formatter_test.go
TestFormatResult_TextFiles()     // Text files only
TestFormatResult_Directory()     // Directory only
TestFormatResult_Mixed()         // Mixed selection
TestFormatResult_MultipleDirectories() // Error case
TestFormatResult_Empty()         // No selection

// result_test.go
TestWriteTempFileList()          // Temp file creation
TestWriteTempFileList_Permissions() // File permissions (0600)
TestPipeDelimitedOutput()        // Output format
```

#### 6. opener package (5-7 tests)
```go
// opener_test.go
TestGetOpenCommand_Darwin()      // macOS
TestGetOpenCommand_Linux()       // Linux
TestGetOpenCommand_Unsupported() // Other platforms
TestOpenFiles_Success()          // Successful open
TestOpenFiles_Partial()          // Some files fail
TestOpenFiles_NoOpen()           // --no-open flag
```

#### 7. exec package (5-8 tests)
```go
// command_test.go
TestIsAvailable_Exists()         // Command exists
TestIsAvailable_NotExists()      // Command missing
TestIsAvailable_Cached()         // Caching works
TestExecute_Success()            // Successful execution
TestExecute_Failure()            // Command failure
TestExecute_Timeout()            // Context timeout
```

### Integration Tests (~20 tests)

#### File Listing Integration (8 tests)
```go
// integration/lister_test.go
TestFileListingIntegration_SystemMode()
TestFileListingIntegration_PWDMode()
TestFileListingIntegration_SubdirsMode()
TestFileListingIntegration_Excludes()
TestFileListingIntegration_RealFilesystem()
TestFileListingIntegration_LargeDirectory() // Performance
TestFileListingIntegration_SymbolicLinks()
TestFileListingIntegration_HiddenFiles()
```

#### Preview Integration (6 tests)
```go
// integration/preview_test.go
TestPreviewIntegration_TextFile()
TestPreviewIntegration_Directory()
TestPreviewIntegration_Image()   // Requires tiv
TestPreviewIntegration_PDF()     // Requires pdftotext
TestPreviewIntegration_Timeout()
TestPreviewIntegration_OutputSize() // >10k lines
```

#### End-to-End (6 tests)
```go
// integration/e2e_test.go
TestE2E_TextFileSelection()      // Scripted fzf input
TestE2E_DirectorySelection()
TestE2E_MixedSelection()
TestE2E_Cancellation()
TestE2E_PipeDelimitedOutput()
TestE2E_TempFileCleanup()
```

### Golden File Testing

For output format verification:

```go
// testdata/golden/
// - system_mode.txt
// - pwd_mode.txt
// - subdirs_mode.txt
// - pipe_delimited_output.txt

func TestFormatResult_Golden(t *testing.T) {
    tests := []struct {
        name       string
        input      []CategorizedFile
        goldenFile string
    }{
        {
            name:       "system mode",
            input:      loadFixture("system_mode.json"),
            goldenFile: "testdata/golden/system_mode.txt",
        },
        // ... more test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := FormatResult(tt.input)
            golden := loadGoldenFile(tt.goldenFile)
            assert.Equal(t, golden, result)
        })
    }
}
```

### Test Data Structure
```
testdata/
├── files/
│   ├── text/
│   │   ├── sample.txt
│   │   ├── sample.md
│   │   ├── sample.json
│   │   └── sample.go
│   ├── images/
│   │   ├── sample.png
│   │   └── sample.jpg
│   ├── pdfs/
│   │   └── sample.pdf
│   └── binaries/
│       └── sample.bin
├── directories/
│   ├── node_modules/     # Excluded directory
│   ├── .git/             # Excluded directory
│   ├── regular/          # Regular directory
│   └── nested/deep/path/ # Nested structure
├── golden/
│   ├── system_mode.txt
│   ├── pwd_mode.txt
│   ├── subdirs_mode.txt
│   └── pipe_delimited_output.txt
├── fixtures/
│   ├── fd_output_system.txt    # Pre-captured fd output
│   ├── fd_output_pwd.txt
│   └── fd_output_subdirs.txt
└── expected/
    └── categorization.json
```

### Manual Testing Checklist

For each shell (bash, zsh, fish) - 30 test cases total:

**Preview Tests (3 per shell = 9 total)**
- [ ] Preview text files with syntax highlighting
- [ ] Preview PDF files (text extraction)
- [ ] Preview directories (colored listing)
- [ ] Preview images (terminal rendering if tiv available)
- [ ] Preview non-previewable files (shows message)

**Text File Selection (3 per shell = 9 total)**
- [ ] Open single text file in $EDITOR
- [ ] Open multiple text files in $EDITOR (splits/tabs)
- [ ] Files with spaces in names handled correctly

**Directory Navigation (2 per shell = 6 total)**
- [ ] cd to single directory
- [ ] Error message when multiple directories selected

**Media File Handling (2 per shell = 6 total)**
- [ ] Open single PDF in system default app
- [ ] Open multiple PDFs in system default app
- [ ] Open images in Preview/default app
- [ ] Open .key files in Keynote

**Mode Tests (3 per shell = 9 total)**
- [ ] System mode (default) searches everywhere
- [ ] `-o` flag lists current directory only
- [ ] `-s` flag lists subdirectories recursively

**Edge Cases (3 per shell = 9 total)**
- [ ] Cancellation (Ctrl-C) cleans up temp files
- [ ] Special entries (HOME, .., /) work correctly
- [ ] Large file lists (>1000 files) perform well

### Automated Integration Test Harness

For scripted fzf testing:

```go
// integration/fzf_harness.go
type FzfHarness struct {
    input      []string
    selections []int  // Indexes of items to select
}

func (h *FzfHarness) Run() ([]string, error) {
    // Create script that:
    // 1. Launches fzf
    // 2. Sends keypresses to navigate
    // 3. Sends ENTER to select
    // 4. Captures output

    // Using expect-like functionality or pre-scripted input
}
```

### Continuous Testing

**Pre-commit Hook:**
```bash
#!/bin/bash
# Run unit tests before commit
go test ./... -short
```

**CI Pipeline (GitHub Actions):**
```yaml
test:
  strategy:
    matrix:
      os: [ubuntu-latest, macos-latest]
      go: [1.21, 1.22]
  steps:
    - name: Unit Tests
      run: go test ./... -race -coverprofile=coverage.txt
    - name: Integration Tests
      run: go test ./integration/... -tags=integration
```

### Coverage Requirements

- **Overall:** >80% line coverage
- **Critical packages:** >90% (config, files, output)
- **Preview package:** >75% (external dependency variations)
- **fzf package:** >70% (UI interactions harder to test)

Migration Path
--------------

### Phase 1: Parallel Installation
1. Install Go binary alongside existing shell scripts
2. Create `cmdk-go` wrapper function for testing
3. Users can test with `cmdk-go` while keeping `cmdk` working
4. Gather feedback and fix bugs

### Phase 2: Beta Testing
1. Update README with Go version installation instructions
2. Mark shell version as "legacy" but still maintained
3. Encourage users to try Go version and report issues
4. Fix compatibility issues

### Phase 3: Migration
1. Update default installation to Go version
2. Rename `cmdk` → `cmdk-legacy` in shell wrappers
3. Use `cmdk` for Go version
4. Provide migration script to update shell configs

### Phase 4: Deprecation
1. Archive shell scripts in `legacy/` directory
2. Update README to focus on Go version
3. Keep shell scripts for historical reference
4. Remove shell version from main installation after 6-12 months

### Backward Compatibility Considerations

**Keep Compatible:**
- Pipe-delimited output format (`text_files_path|directory_path`)
- Flag behavior: `-o` and `-s`
- Environment variable: `$CMDK_DIRPATH` (though less relevant for Go binary)
- Shell wrapper interface

**Can Change:**
- Internal implementation
- Error messages (improve clarity)
- Add new features without breaking existing

Design Decisions
-----------------

All open questions have been resolved to provide clear direction for implementation:

### 1. Binary Installation Location
**Decision:** `~/.local/bin/cmdk` with Homebrew formula in v1.1

**Rationale:** User-local installation requires no sudo, standard location ($PATH typically includes it), and Homebrew provides easy updates.

### 2. Configuration File Format
**Decision:** No config file in v1.0, defer to v2.0 if requested

**Rationale:** Keep v1 simple, focused on feature parity. Most configuration can be done via environment variables.

### 3. Logging and Debugging
**Decision:** Use structured logging (log/slog) to `~/.cache/cmdk/debug.log` when `CMDK_DEBUG=1`, stderr for user-facing errors only

**Rationale:**
- Separates debug logs from actual errors
- Persistent logs enable post-mortem debugging
- Structured logs are easier to parse and analyze
- Add `--log-level` flag for granular control (debug, info, warn, error)

### 4. Cross-Platform Support
**Decision:** macOS and Linux only for v1.0

**Rationale:** Matches current shell version scope, avoids Windows-specific complexity initially. Can add Windows support in v2 if there's demand.

### 5. Preview Command Architecture
**Decision:** Hidden Cobra subcommand `cmdk preview <path>`

**Rationale:** Single binary, clean architecture, uses os.Executable() for self-discovery.

### 6. Dependency Management for Optional Tools
**Decision:** Check on first use, cache availability in memory for session, degrade gracefully

**Rationale:** No startup penalty, efficient, user-friendly. Add `cmdk health` command to check all dependencies upfront.

### 7. MIME Type Detection
**Decision:** Use `github.com/gabriel-vasile/mimetype` library with `file` command fallback

**Rationale:** Pure Go is faster, more portable, and eliminates external dependency. Fallback provides compatibility for edge cases.

### 8. Editor Handling
**Decision:** Shell wrapper handles $EDITOR parsing and invocation

**Rationale:** Maintains current approach, avoids shell parsing complexity in Go, leverages shell's built-in word splitting.

### 9. Testing with fzf
**Decision:** Mock fzf via interface for unit tests, manual checklist for integration tests, helper scripts for reproducible scenarios

**Rationale:** Balances automated coverage with practical testing limitations. Interface abstraction enables comprehensive unit testing.

### 10. Performance Optimization
**Decision:** Use fd as-is, stream output directly to fzf, add performance benchmarks to detect regressions

**Rationale:** fd is already optimized. Add metrics to identify issues rather than premature optimization.

**Performance Targets:**
- Startup time: <100ms (excluding fzf launch)
- File listing for 10k files: <500ms
- Preview generation: <50ms for text, <200ms for images/PDFs
- Memory usage: <50MB for typical workloads

Implementation Priorities
-------------------------

### Must Have (v1.0)
- All current functionality preserved
- Three modes: system, -o, -s
- File categorization (directories, text files, open targets)
- Preview support (text, directories, images, PDFs)
- Shell integration (bash, zsh, fish)
- Backward compatible output format
- Basic error handling and logging

### Should Have (v1.1)
- Comprehensive test coverage
- Installation script
- Homebrew formula
- Improved error messages
- Debug mode (`CMDK_DEBUG=1`)

### Could Have (v2.0)
- Configuration file support
- Custom exclude patterns
- Favorites/history feature (from TODO list)
- Custom open commands (from TODO list)
- Windows support
- Pure Go MIME detection (no `file` dependency)

### Won't Have (Initially)
- Built-in fzf (keep as external dependency)
- Built-in fd (keep as external dependency)
- GUI mode
- Web interface
- Plugin system

Health Check Command
---------------------

A `cmdk health` command will verify all dependencies and configuration:

```go
// cmd/health.go
var healthCmd = &cobra.Command{
    Use:   "health",
    Short: "Check dependencies and configuration",
    RunE: func(cmd *cobra.Command, args []string) error {
        return runHealthCheck()
    },
}

func runHealthCheck() error {
    fmt.Println("cmdk Health Check")
    fmt.Println("=================\n")

    allOk := true

    // Check required dependencies
    fmt.Println("Required Dependencies:")
    allOk = checkRequired("fzf", exec.FzfCommand) && allOk
    allOk = checkRequired("fd", exec.FdCommand) && allOk

    // Check optional dependencies
    fmt.Println("\nOptional Dependencies:")
    checkOptional("bat", exec.BatCommand, "Text file syntax highlighting")
    checkOptional("tiv", exec.TivCommand, "Terminal image preview")
    checkOptional("pdftotext", exec.PdftotextCmd, "PDF text extraction")

    // Check configuration
    fmt.Println("\nConfiguration:")
    cfg, err := config.New()
    if err != nil {
        fmt.Printf("  ✗ Configuration: %v\n", err)
        allOk = false
    } else if err := cfg.Validate(); err != nil {
        fmt.Printf("  ✗ Configuration: %v\n", err)
        allOk = false
    } else {
        fmt.Printf("  ✓ Configuration valid\n")
        fmt.Printf("    - Mode: %v\n", cfg.Mode)
        fmt.Printf("    - HOME: %s\n", cfg.HomeDir)
        fmt.Printf("    - PWD: %s\n", cfg.PWD)
    }

    // Check shell integration
    fmt.Println("\nShell Integration:")
    shell := shell.DetectShell()
    fmt.Printf("  ✓ Detected shell: %s\n", shell)

    // Check temp directory
    fmt.Println("\nTemp Files:")
    tmpDir := os.TempDir()
    if info, err := os.Stat(tmpDir); err != nil {
        fmt.Printf("  ✗ Temp directory: %v\n", err)
        allOk = false
    } else if !info.IsDir() {
        fmt.Printf("  ✗ Temp directory is not a directory: %s\n", tmpDir)
        allOk = false
    } else {
        fmt.Printf("  ✓ Temp directory: %s\n", tmpDir)

        // Count stale temp files
        staleCount := countStaleTempFiles()
        if staleCount > 0 {
            fmt.Printf("  ⚠ Found %d stale temp file(s) (>1 hour old)\n", staleCount)
            fmt.Printf("    Run 'cmdk cleanup' to remove them\n")
        }
    }

    // Check platform
    fmt.Println("\nPlatform:")
    openCmd, err := opener.GetOpenCommand()
    if err != nil {
        fmt.Printf("  ✗ Platform support: %v\n", err)
        allOk = false
    } else {
        fmt.Printf("  ✓ Platform: %s\n", runtime.GOOS)
        fmt.Printf("  ✓ Open command: %s\n", openCmd)
    }

    // Summary
    fmt.Println()
    if allOk {
        fmt.Println("✓ All checks passed")
        return nil
    } else {
        fmt.Println("✗ Some checks failed")
        return fmt.Errorf("health check failed")
    }
}

func checkRequired(name string, cmd exec.ExternalCommand) bool {
    if cmd.IsAvailable() {
        version := getVersion(cmd)
        fmt.Printf("  ✓ %s: %s\n", name, version)
        return true
    } else {
        fmt.Printf("  ✗ %s: not found in PATH\n", name)
        fmt.Printf("    Install: brew install %s\n", name)
        return false
    }
}

func checkOptional(name string, cmd exec.ExternalCommand, purpose string) {
    if cmd.IsAvailable() {
        version := getVersion(cmd)
        fmt.Printf("  ✓ %s: %s (%s)\n", name, version, purpose)
    } else {
        fmt.Printf("  - %s: not found (%s)\n", name, purpose)
        fmt.Printf("    Install: brew install %s\n", name)
    }
}

func getVersion(cmd exec.ExternalCommand) string {
    // Try common version flags
    for _, flag := range []string{"--version", "-version", "version", "-V"} {
        stdout, _, err := cmd.Execute(context.Background(), flag)
        if err == nil && stdout != "" {
            // Return first line only
            lines := strings.Split(stdout, "\n")
            if len(lines) > 0 {
                return lines[0]
            }
        }
    }
    return "installed"
}
```

**Example Output:**
```
cmdk Health Check
=================

Required Dependencies:
  ✓ fzf: 0.44.0
  ✓ fd: fd 8.7.0

Optional Dependencies:
  ✓ bat: bat 0.24.0 (Text file syntax highlighting)
  - tiv: not found (Terminal image preview)
    Install: brew install tiv
  ✓ pdftotext: pdftotext version 22.12.0 (PDF text extraction)

Configuration:
  ✓ Configuration valid
    - Mode: System
    - HOME: /Users/alice
    - PWD: /Users/alice/projects

Shell Integration:
  ✓ Detected shell: zsh

Temp Files:
  ✓ Temp directory: /tmp
  ⚠ Found 3 stale temp file(s) (>1 hour old)
    Run 'cmdk cleanup' to remove them

Platform:
  ✓ Platform: darwin
  ✓ Open command: open

✓ All checks passed
```

Dependencies and External Tools
--------------------------------

### Go Dependencies
- `github.com/spf13/cobra` - CLI framework
- `github.com/mieubrisse/stacktrace` - Error handling with stack traces
- `github.com/gabriel-vasile/mimetype` - Pure Go MIME type detection
- `log/slog` - Structured logging (Go 1.21+ stdlib)
- Standard library: `os`, `os/exec`, `path/filepath`, `io`, `strings`, `context`, `sync`, etc.

### External Runtime Dependencies
**Required:**
- `fzf` - Fuzzy finder (core UI component)
- `fd` - Fast file finder (file listing with color support)

**Optional:**
- `bat` - Syntax-highlighted file viewer (text preview, fallback to `cat`)
- `tiv` - Terminal image viewer (image preview, fallback to placeholder message)
- `pdftotext` (from poppler) - PDF text extraction (PDF preview, fallback to placeholder)
- `file` - MIME type detection (fallback for mimetype library)

**Availability Checking:**
- Required tools checked at startup (fail fast if missing)
- Optional tools checked on first use (cached in memory for session)
- `cmdk health` command provides comprehensive dependency report

### Build Dependencies
- Go 1.21+ (for log/slog and latest performance improvements)
- Standard Go toolchain (`go build`, `go test`, `go mod`)

### Installation Requirements
- Homebrew (macOS) or package manager (Linux) for external dependencies
- `~/.local/bin` in user's PATH (or install location of choice)

Success Criteria
----------------

### Functional Success
- [ ] All current features work in Go version
- [ ] Shell integration works for bash, zsh, fish
- [ ] All items in manual testing checklist pass (30 tests)
- [ ] All three modes work correctly (-o, -s, default)
- [ ] File categorization matches shell version behavior
- [ ] Preview functionality works for all file types
- [ ] Temp file cleanup works reliably
- [ ] Error handling is robust and clear
- [ ] `cmdk health` command provides accurate diagnostics

### Performance Success
- [ ] Startup time <100ms (excluding fzf launch)
- [ ] File listing for 1,000 files: <200ms
- [ ] File listing for 10,000 files: <500ms
- [ ] Preview generation: <50ms for text files (with bat)
- [ ] Preview generation: <200ms for images (with tiv)
- [ ] Preview generation: <200ms for PDFs (with pdftotext)
- [ ] Memory usage: <50MB for typical workloads (1k files)
- [ ] Memory usage: <100MB for large workloads (10k files)
- [ ] No memory leaks (valgrind or Go race detector)
- [ ] Performance equal to or better than shell version

**Benchmarking Strategy:**
```go
// Add benchmarks in *_test.go files
func BenchmarkListFiles_1000Files(b *testing.B) {
    cfg := setupTestConfig()
    for i := 0; i < b.N; i++ {
        ListFiles(cfg, exec.FdCommand)
    }
}

func BenchmarkPreview_TextFile(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Preview(context.Background(), "testdata/sample.txt")
    }
}
```

### Quality Success
- [ ] Overall test coverage >80%
- [ ] Critical packages (config, files, output) >90% coverage
- [ ] All exported functions have tests
- [ ] No known bugs
- [ ] Clear, actionable error messages
- [ ] Clean, maintainable code following Go idioms
- [ ] Well-documented (README, code comments, examples)
- [ ] Passes `go vet` with no warnings
- [ ] Passes `golangci-lint` with no errors
- [ ] All package dependencies up to date

### Code Quality Metrics
- [ ] Cyclomatic complexity <15 per function
- [ ] No functions >100 lines
- [ ] No files >500 lines
- [ ] All errors properly handled (no naked returns on errors)
- [ ] All resources properly cleaned up (defer, cleanup registry)

### Adoption Success
- [ ] Installation is simple (single command or Homebrew formula)
- [ ] Migration path is clear and documented
- [ ] Migration script works correctly
- [ ] Side-by-side installation works without conflicts
- [ ] Users report positive feedback
- [ ] No major complaints about missing features
- [ ] GitHub issues resolved within 1 week
- [ ] At least 80% of test users successfully migrate

Next Steps
----------

1. **Get approval on this plan**
   - Review design decisions
   - Answer open questions
   - Adjust priorities if needed

2. **Set up development environment**
   - Initialize Go module
   - Set up project structure
   - Install dependencies

3. **Begin Phase 1 implementation**
   - Create core infrastructure
   - Implement configuration management
   - Set up Cobra commands

4. **Iterate through phases**
   - Implement each phase sequentially
   - Test thoroughly at each stage
   - Adjust plan based on discoveries

5. **Beta release**
   - Release to small group of users
   - Gather feedback
   - Fix bugs and polish

6. **Public release**
   - Update README
   - Create release notes
   - Announce on GitHub

Estimated Total Timeline
------------------------
- **Core implementation:** 20-30 hours
- **Testing and bug fixes:** 8-12 hours
- **Documentation:** 4-6 hours
- **Beta testing and iteration:** 8-12 hours
- **Total:** 40-60 hours over 2-4 weeks (part-time development)

Risks and Mitigations
----------------------

### Risk 1: Shell Integration Complexity
**Risk:** Shell wrapper complexity may increase or subtle bugs may emerge
**Mitigation:** Keep shell wrappers simple, thoroughly test on all three shells, maintain backward compatible output format
**Status:** MITIGATED - Pipe-delimited format is simple and well-specified

### Risk 2: External Dependency Changes
**Risk:** fzf or fd may change behavior or APIs
**Mitigation:** Document required versions, test with common versions, consider vendoring or providing binaries
**Status:** MONITORED - Document minimum versions in README

### Risk 3: Platform-Specific Issues
**Risk:** macOS-specific features may break on Linux or vice versa
**Mitigation:** Test on both platforms, use conditional compilation, document platform requirements
**Status:** MITIGATED - `runtime.GOOS` switches, CI tests both platforms

### Risk 4: Performance Regression
**Risk:** Go version may be slower than shell version
**Mitigation:** Benchmark critical paths, profile if issues arise, optimize hot paths
**Status:** MITIGATED - Benchmarks in place, streaming architecture, performance targets defined

### Risk 5: User Adoption
**Risk:** Users may not want to migrate from working shell version
**Mitigation:** Clear value proposition (better error handling, easier to extend), smooth migration path, maintain shell version in parallel
**Status:** MITIGATED - 4-phase migration plan, side-by-side installation

### Risk 6: Feature Creep
**Risk:** Temptation to add features during implementation
**Mitigation:** Stick to plan, defer new features to v2, focus on parity first
**Status:** MITIGATED - Clear v1 vs v2 scope definition, phase checklists

### Risk 7: fzf Integration Complexity (NEW)
**Risk:** fzf subprocess management, preview command coordination, signal handling
**Mitigation:** Detailed specification now in place, context-based cancellation, signal handling
**Status:** MITIGATED - Complete specification added

### Risk 8: Concurrency Bugs (NEW)
**Risk:** Race conditions in preview command, temp file handling, signal handling
**Mitigation:** Cleanup registry pattern, stateless preview, `go test -race` required
**Status:** MITIGATED - Cleanup registry, stateless design, race detector in CI

Implementation Notes for Tricky Areas
--------------------------------------

### Handling ANSI Color Codes in fd Output

**Challenge:** fd outputs ANSI color codes with `--color=always`. These must be preserved for fzf display but can complicate parsing.

**Solution:**
```go
// Don't strip ANSI codes - pass through directly to fzf
func parseFileList(output string) []string {
    lines := strings.Split(output, "\n")
    var files []string
    for _, line := range lines {
        // Keep ANSI codes intact
        trimmed := strings.TrimSpace(line)
        if trimmed != "" {
            files = append(files, line) // Original line with colors
        }
    }
    return files
}
```

**Key Points:**
- Use `--color=always` flag for fd
- Pass output directly to fzf without stripping codes
- fzf handles ANSI codes via `--ansi` flag
- Only strip codes if needed for file operations (use regex: `\x1b\[[0-9;]*m`)

### Shell Word Splitting Edge Cases

**Challenge:** File paths with spaces, tabs, newlines must be handled correctly when passing to $EDITOR.

**Solution:** Let shell wrapper handle it, pass via temp file with newline-separated paths:
```bash
# In cmdk.sh
while IFS= read -r line || [ -n "$line" ]; do
    text_files+=("$line")  # Proper array handling preserves spaces
done < "$text_files_path"

# Open with editor - shell handles word splitting of $EDITOR
"${editor_cmd[@]}" "${text_files[@]}"
```

**Key Points:**
- Don't escape paths in Go - write them verbatim to temp file
- Use `IFS=` in shell to prevent word splitting on spaces
- Use array syntax to preserve arguments with spaces
- Let shell handle $EDITOR parsing (e.g., "vim -O")

### HOME Directory Special Cases

**Challenge:** When PWD is HOME, need special handling for excludes and display.

**Solution:**
```go
func listFiles(cfg *config.Config) ([]string, error) {
    var excludes []string
    excludes = append(excludes, cfg.CommonExcludes...)

    // Add HOME-specific excludes only when in HOME
    if cfg.PWD == cfg.HomeDir {
        excludes = append(excludes, cfg.HomeExcludes...)
    }

    // ... build fd command with excludes ...

    // After running fd, add back excluded dirs at depth 1
    if cfg.PWD == cfg.HomeDir {
        for _, dir := range cfg.HomeExcludes {
            dirPath := filepath.Join(cfg.HomeDir, dir)
            if fi, err := os.Stat(dirPath); err == nil && fi.IsDir() {
                results = append(results, dir) // Just the name, not full path
            }
        }
    }

    return results, nil
}
```

**Key Points:**
- Conditionally apply HOME excludes only when `PWD == HomeDir`
- Add back excluded directories (just names) for navigation
- "HOME" special entry always added (not same as HOME directory path)

### Preview Command Self-Discovery

**Challenge:** Preview command needs to call itself (`cmdk preview <path>`), but must find its own binary path.

**Solution:**
```go
func buildPreviewCommand() (string, error) {
    exePath, err := os.Executable()
    if err != nil {
        return "", stacktrace.Propagate(err, "failed to find cmdk executable")
    }

    // Resolve symlinks (important for Homebrew installations)
    exePath, err = filepath.EvalSymlinks(exePath)
    if err != nil {
        return "", stacktrace.Propagate(err, "failed to resolve symlinks")
    }

    // Quote path to handle spaces
    quotedPath := fmt.Sprintf("'%s'", strings.ReplaceAll(exePath, "'", "'\\''"))

    return fmt.Sprintf("%s preview {}", quotedPath), nil
}
```

**Key Points:**
- Use `os.Executable()` to find own path
- Resolve symlinks (Homebrew installs symlink to /usr/local/bin)
- Quote path properly for shell execution
- Handle spaces in installation path
- `{}` is fzf placeholder for selected item

### Temp File Race Conditions

**Challenge:** Multiple cmdk instances running simultaneously could conflict on temp file names.

**Solution:**
```go
// os.CreateTemp already handles this - uses PID and randomness
tmpFile, err := os.CreateTemp(os.TempDir(), "cmdk-*.txt")

// For extra safety, cleanup registry tracks by PID
var cleanupRegistry = struct {
    sync.Mutex
    files map[string]bool  // Track files created by this process
}{
    files: make(map[string]bool),
}

func registerTempFile(path string) {
    cleanupRegistry.Lock()
    defer cleanupRegistry.Unlock()
    cleanupRegistry.files[path] = true
}

// On cleanup, only delete files we created
func cleanupOwnTempFiles() {
    cleanupRegistry.Lock()
    defer cleanupRegistry.Unlock()

    for path := range cleanupRegistry.files {
        os.Remove(path)
    }
}
```

**Key Points:**
- `os.CreateTemp` uses PID and random number - no collisions
- Track temp files created by current process only
- Don't delete temp files from other cmdk instances
- Shell wrapper cleans up after editor closes

### MIME Type Detection Fallback Chain

**Challenge:** Need reliable MIME detection across platforms with graceful fallback.

**Solution:**
```go
var (
    mimeCache = struct {
        sync.RWMutex
        cache map[string]string
    }{
        cache: make(map[string]string),
    }
)

func DetectMimeType(path string) (string, error) {
    // Check cache first
    mimeCache.RLock()
    if mimeType, ok := mimeCache.cache[path]; ok {
        mimeCache.RUnlock()
        return mimeType, nil
    }
    mimeCache.RUnlock()

    // Try Go library first (fast, pure Go)
    mtype, err := mimetype.DetectFile(path)
    if err == nil && mtype.String() != "application/octet-stream" {
        mimeType := mtype.String()
        cacheMimeType(path, mimeType)
        return mimeType, nil
    }

    // Fallback to file command (slower, but more accurate)
    if exec.FileCommand.IsAvailable() {
        stdout, _, err := exec.FileCommand.Execute(
            context.Background(),
            "-b", "--mime-type", path,
        )
        if err == nil {
            mimeType := strings.TrimSpace(stdout)
            cacheMimeType(path, mimeType)
            return mimeType, nil
        }
    }

    // Last resort: guess from extension
    mimeType := guessFromExtension(path)
    cacheMimeType(path, mimeType)
    return mimeType, nil
}

func cacheMimeType(path, mimeType string) {
    mimeCache.Lock()
    defer mimeCache.Unlock()
    mimeCache.cache[path] = mimeType
}
```

**Key Points:**
- Three-tier fallback: Go library → file command → extension
- Cache results (same file checked multiple times during preview navigation)
- Thread-safe cache with RWMutex
- Go library is fast but less accurate for uncommon types
- file command is accurate but slower (subprocess spawn)

Conclusion
----------

This plan provides a comprehensive roadmap for reimplementing cmdk in Go while maintaining backward compatibility and improving maintainability. The phased approach allows for incremental progress, testing, and feedback. The modular architecture supports future enhancements and cross-platform support.

The key success factors are:
1. Maintaining feature parity with shell version
2. Keeping shell integration simple and reliable
3. Providing graceful degradation for optional dependencies
4. Thorough testing across platforms and shells
5. Clear migration path for users

With this plan, cmdk can evolve into a more maintainable, extensible, and robust tool while preserving the excellent user experience of the current shell implementation.
