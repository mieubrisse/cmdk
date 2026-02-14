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

Implementation Approach
-----------------------

### Phase 1: Project Setup and Core Infrastructure
**Goals:**
- Set up Go module with Cobra
- Implement configuration management
- Create basic project structure
- Add error handling with stacktrace library

**Deliverables:**
- `go.mod` with dependencies (cobra, stacktrace)
- `internal/config` package with Config struct and constants
- `main.go` with basic Cobra setup
- `cmd/root.go` with flag parsing (-o, -s)

**Time Estimate:** 2-3 hours

### Phase 2: File Listing
**Goals:**
- Implement fd-based file listing
- Handle exclude directories
- Re-add excluded directories at depth 1
- Support three modes (system, pwd, subdirs)

**Deliverables:**
- `internal/files/lister.go` with ListFiles function
- Unit tests for exclude logic
- Integration tests with real filesystem

**Time Estimate:** 4-6 hours

**Key Implementation Details:**
- Use `os/exec` to run fd command
- Parse fd output (ANSI color codes included)
- Handle HOME-specific excludes when PWD == HOME
- Add special entries (HOME, .., /, /tmp/)

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

### Unit Tests

1. **config package**
   - Test exclude list generation
   - Test mode selection
   - Test configuration loading

2. **files package**
   - Test file listing with various modes
   - Test exclude logic
   - Test MIME type detection
   - Test categorization logic
   - Mock fd command output

3. **preview package**
   - Test preview dispatching
   - Test each preview type
   - Test fallback behavior
   - Mock external commands (bat, tiv, pdftotext)

4. **output package**
   - Test result formatting
   - Test temp file creation
   - Test directory validation
   - Test pipe-delimited output format

### Integration Tests

1. **File listing integration**
   - Create test directory structure
   - Run ListFiles with real fd
   - Verify correct files listed
   - Verify excludes work correctly

2. **End-to-end flow** (manual testing required)
   - Test with real fzf
   - Test all three modes
   - Test categorization with real files
   - Test shell integration

### Test Data Structure
```
testdata/
├── files/
│   ├── text/
│   │   ├── sample.txt
│   │   ├── sample.md
│   │   └── sample.json
│   ├── images/
│   │   ├── sample.png
│   │   └── sample.jpg
│   ├── pdfs/
│   │   └── sample.pdf
│   └── binaries/
│       └── sample.bin
├── directories/
│   ├── node_modules/  (excluded)
│   ├── .git/          (excluded)
│   └── regular/
└── expected/
    └── output_samples.txt
```

### Testing Checklist (adapted from testing-checklist.md)

For each shell (bash, zsh, fish):
- [ ] Preview text files correctly
- [ ] Preview PDFs correctly
- [ ] Preview directories correctly
- [ ] Open single text file in $EDITOR
- [ ] Open multiple text files in $EDITOR
- [ ] Open single PDF in Preview/default app
- [ ] Open multiple PDFs in Preview/default app
- [ ] cd to single directory
- [ ] Error on multiple directory selection

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

Open Questions and Design Decisions
------------------------------------

### 1. Binary Installation Location
**Question:** Where should the Go binary be installed?

**Options:**
- `/usr/local/bin/cmdk` (standard, requires sudo)
- `~/.local/bin/cmdk` (user-local, no sudo)
- `~/.cmdk/bin/cmdk` (alongside shell scripts)
- Homebrew formula (future)

**Recommendation:** Start with `~/.local/bin/cmdk`, add Homebrew formula later

### 2. Configuration File Format
**Question:** Should we support a config file for customization?

**Options:**
- No config file initially (keep simple)
- YAML config: `~/.config/cmdk/config.yaml`
- TOML config: `~/.config/cmdk/config.toml`
- JSON config: `~/.config/cmdk/config.json`

**Recommendation:** No config file in v1, add in v2 if requested

### 3. Logging and Debugging
**Question:** How should errors and debug info be handled?

**Options:**
- Stderr for all errors (simple)
- Log file: `~/.cmdk/debug.log` (persistent)
- Environment variable: `CMDK_DEBUG=1` for verbose output
- Both: stderr for errors, optional debug file

**Recommendation:** Stderr for errors, `CMDK_DEBUG=1` for verbose output to stderr

### 4. Cross-Platform Support
**Question:** How aggressively should we support Windows?

**Options:**
- macOS/Linux only (matches current shell version)
- Windows with WSL only (minimal effort)
- Native Windows support (significant effort)

**Recommendation:** macOS/Linux in v1, Windows WSL in v2, native Windows in v3 (if demand exists)

### 5. Preview Command Architecture
**Question:** How should preview command be integrated?

**Options:**
- Hidden subcommand: `cmdk preview <path>` (clean)
- Separate binary: `cmdk-preview <path>` (more complexity)
- Embedded in main binary with flag: `cmdk --preview <path>` (cluttered)

**Recommendation:** Hidden subcommand (clean, single binary)

### 6. Dependency Management for Optional Tools
**Question:** How should optional dependencies (bat, tiv, pdftotext) be handled?

**Options:**
- Required: fail if missing (too strict)
- Optional: degrade gracefully (user-friendly)
- Check at startup and warn (informative but noisy)
- Check on first use and cache availability (lazy, efficient)

**Recommendation:** Optional with graceful degradation, check on first use

### 7. MIME Type Detection
**Question:** Should we use `file` command or Go library?

**Options:**
- `file` command (matches shell version, external dependency)
- Go library like `github.com/gabriel-vasile/mimetype` (pure Go, no external deps)
- Hybrid: Go library with `file` fallback

**Recommendation:** Start with `file` command (proven, matches current), consider Go library in v2

### 8. Editor Handling
**Question:** How should we handle $EDITOR with flags (e.g., "vim -O")?

**Options:**
- Split on space (simple, breaks on paths with spaces)
- Use shell parsing (complex, requires shell dependency)
- Pass to shell wrapper (current approach, works)

**Recommendation:** Pass to shell wrapper (maintain current approach)

### 9. Testing with fzf
**Question:** How to test fzf integration without user interaction?

**Options:**
- Mock fzf output (unit tests only, doesn't test real integration)
- Automated UI testing with expect/pexpect (complex)
- Manual testing checklist (simple, proven)
- Optional: headless fzf tests with piped input

**Recommendation:** Mock for unit tests, manual checklist for integration, consider headless automation later

### 10. Performance Optimization
**Question:** Should we optimize file listing for large directories?

**Options:**
- Use fd as-is (current approach, already fast)
- Parallel directory traversal (premature optimization)
- Caching (adds complexity)
- Stream results to fzf (matches current behavior)

**Recommendation:** Use fd as-is, optimize only if performance issues reported

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

Dependencies and External Tools
--------------------------------

### Go Dependencies
- `github.com/spf13/cobra` - CLI framework
- `github.com/mieubrisse/stacktrace` - Error handling
- Standard library: `os`, `os/exec`, `path/filepath`, `io`, `strings`, etc.

### External Runtime Dependencies
**Required:**
- `fzf` - Fuzzy finder (core UI)
- `fd` - File finder (file listing)

**Optional:**
- `bat` - Syntax highlighting (text preview, fallback to cat)
- `tiv` - Image viewer (image preview, fallback to placeholder)
- `pdftotext` (poppler) - PDF preview (fallback to placeholder)
- `file` - MIME detection (may use Go library in future)

### Build Dependencies
- Go 1.21+ (for latest features and performance)
- Standard Go toolchain (go build, go test)

Success Criteria
----------------

### Functional Success
- [ ] All current features work in Go version
- [ ] Shell integration works for bash, zsh, fish
- [ ] All items in testing checklist pass
- [ ] Performance is equal to or better than shell version
- [ ] Error handling is robust and clear

### Quality Success
- [ ] Test coverage >80%
- [ ] No known bugs
- [ ] Clear error messages
- [ ] Clean, maintainable code
- [ ] Well-documented

### Adoption Success
- [ ] Installation is simple (single command)
- [ ] Migration path is clear
- [ ] Users report positive feedback
- [ ] No major complaints about missing features

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

### Risk 2: External Dependency Changes
**Risk:** fzf or fd may change behavior or APIs
**Mitigation:** Document required versions, test with common versions, consider vendoring or providing binaries

### Risk 3: Platform-Specific Issues
**Risk:** macOS-specific features may break on Linux or vice versa
**Mitigation:** Test on both platforms, use conditional compilation, document platform requirements

### Risk 4: Performance Regression
**Risk:** Go version may be slower than shell version
**Mitigation:** Benchmark critical paths, profile if issues arise, optimize hot paths

### Risk 5: User Adoption
**Risk:** Users may not want to migrate from working shell version
**Mitigation:** Clear value proposition (better error handling, easier to extend), smooth migration path, maintain shell version in parallel

### Risk 6: Feature Creep
**Risk:** Temptation to add features during implementation
**Mitigation:** Stick to plan, defer new features to v2, focus on parity first

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
