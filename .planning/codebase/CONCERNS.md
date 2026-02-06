# Codebase Concerns

**Analysis Date:** 2026-02-06
**Last Updated:** 2026-02-06

## Tech Debt

**~~No automated testing framework:~~** ✅ RESOLVED
- Fix: Added BATS test suite in `test/` with 21 tests covering list-files, git-files, toggle-state, and preview scripts

**Shell compatibility concerns:**
- Issue: Scripts need to work across Bash and Fish shells
- Files: `cmdk-core.sh`, `cmdk.sh`, `cmdk.fish`
- Impact: Portability issues, different feature sets between shells
- Fix approach: Define minimum shell version requirements, add CI tests for both shells
- Status: Shebang mismatches fixed (`list-files.sh` and `preview.sh` now correctly use `#!/usr/bin/env bash`)

**~~No error handling standardization:~~** ✅ PARTIALLY RESOLVED
- Fix: Added dependency checks for required tools (`fzf`, `fd`, `file`) in `cmdk-core.sh`
- Fix: Added flag validation with clear error messages for unknown flags
- Fix: Added `trap` cleanup in `cmdk-core.sh` for guaranteed state cleanup on exit/error
- Fix: Fixed exit code capture bug (was capturing cleanup exit code, not fzf)
- Fix: Fixed `return` in non-sourced script → `exit 1`
- Remaining: Could add a shared error handling library if more scripts are added

**~~Missing ShellCheck integration:~~** ✅ ALREADY RESOLVED
- ShellCheck CI already exists in `.github/workflows/shellcheck.yml`
- All scripts now pass ShellCheck cleanly

## Known Bugs

**~~Exit code capture bug in cmdk-core.sh:~~** ✅ FIXED
- Was: `exit_code=$?` captured cleanup exit code, not fzf's exit code
- Fix: Exit code now captured immediately after fzf with `|| exit_code=$?`

**~~`return` used in non-sourced script:~~** ✅ FIXED
- Was: `return` in `cmdk-core.sh` which is invoked via `bash`, not sourced
- Fix: Changed to `exit 1`

**~~Home excludes not applied in list-files.sh:~~** ✅ FIXED
- Was: `home_exclude_args` was computed but never passed to the `fd` call when in HOME
- Fix: Now conditionally included in fd invocation when `PWD == HOME`

**~~Incorrect if-then-else in reload-files.sh:~~** ✅ FIXED
- Was: `A && B || C` pattern which is not equivalent to if-then-else
- Fix: Replaced with proper `if/then/else/fi` structure

## Security Considerations

**Unquoted variables in scripts:**
- Risk: Word splitting and glob expansion vulnerabilities
- Files: `list-files.sh` (intentional word-splitting for fd args, documented with shellcheck directives)
- Current mitigation: All intentional word-splitting annotated with `# shellcheck disable=SC2086`
- Status: Reviewed and acceptable for controlled internal values

**~~No input validation:~~** ✅ RESOLVED
- Fix: Added flag validation in `cmdk-core.sh` — only `-o`, `-s`, `-e` accepted
- Fix: Unknown flags now produce clear error and exit 1
- Fix: Validated flags used instead of raw `$*` in fzf commands

**Environment variable parsing:**
- Risk: Uncontrolled environment variables could affect behavior
- Files: `.env` parsing in core
- Current mitigation: .env file is local only
- Recommendations: Validate/whitelist environment variables

## Performance Bottlenecks

**File discovery inefficiency:**
- Problem: `list-files.sh` may scan entire directory trees repeatedly
- Files: `list-files.sh`, `cmdk-core.sh`
- Cause: No caching of file listings
- Improvement path: Add incremental file caching, use git for tracking changes

**Script sourcing overhead:**
- Problem: Each invocation sources multiple files
- Files: All shell entry points
- Cause: No pre-compilation, full parsing on each run
- Improvement path: Consider compiled shell (shc) for production, profile hot paths

## Fragile Areas

**Shell compatibility layer:**
- Files: `cmdk.sh`, `cmdk.fish`, `cmdk-core.sh`
- Why fragile: Different shells have different semantics, behavior divergence
- Safe modification: Create comprehensive tests before changing core
- Test coverage: BATS tests now cover core scripts; cross-shell integration tests still needed

**Action routing system:**
- Files: `cmdk-core.sh` (action dispatch logic)
- Why fragile: Central routing point, affects all commands
- Safe modification: Write integration tests first, test all actions after changes
- Test coverage: Toggle state tests added; full dispatch testing requires fzf stubbing

**File discovery utilities:**
- Files: `list-files.sh`, `git-files.sh`
- Why fragile: Depends on specific Unix tools (find, git)
- Safe modification: Dependency checks now added in `cmdk-core.sh`
- Test coverage: BATS tests cover basic scenarios, edge cases (spaces, special chars)

## Scaling Limits

**Script interpretation overhead:**
- Current capacity: Suitable for small to medium CLI usage
- Limit: May become slow with very large file sets or deep nesting
- Scaling path: Profile hot paths, consider compiled versions or faster language

**Memory usage in large operations:**
- Current capacity: Should be fine for typical usage
- Limit: Loading entire file lists into memory could be issue with huge projects
- Scaling path: Implement streaming/incremental processing

## Dependencies at Risk

**~~Git dependency (silent failure):~~** ✅ PARTIALLY RESOLVED
- Fix: `git-files.sh` already exits non-zero when not in git repo
- Fix: `reload-files.sh` now uses proper if/then/else for git fallback
- Remaining: Could add `git` to dependency checks if git features are required

**Unix utilities:**
- Risk: Depends on find, grep, sed, etc.
- Impact: Breaks on systems without standard Unix tools (minimal containers, Windows WSL)
- Migration plan: `cmdk-core.sh` now checks for `fzf`, `fd`, `file` at startup
- Status: `preview.sh` now has fallbacks for optional tools (`bat`→`cat`, `tiv`, `pdftotext`, `unzip`)

## Missing Critical Features

None identified at this scope level.

## Test Coverage Gaps

**~~Core dispatcher logic:~~** ✅ PARTIALLY RESOLVED
- Added: Toggle state tests, list-files tests, git-files tests, preview tests
- Remaining: Full fzf interaction testing would require fzf stubbing

**Shell-specific integration:**
- What's not tested: Bash-specific vs Fish-specific behavior
- Files: `cmdk.sh`, `cmdk.fish`
- Risk: Commands might work in one shell but not the other
- Priority: High

**~~Error conditions:~~** ✅ PARTIALLY RESOLVED
- Added: Tests for invalid toggle commands, non-git directory handling
- Remaining: Missing file, permission error, missing tool scenarios
- Priority: Medium

**~~Edge cases in file operations:~~** ✅ RESOLVED
- Added: Tests for files with spaces and special characters
- Files: `test/list-files.bats`
- Priority: Medium

---

*Concerns audit: 2026-02-06*
*Last fix pass: 2026-02-06*
