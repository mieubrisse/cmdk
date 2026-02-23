package listing

// commonExcludeDirNames are project directories excluded in all modes.
// These match the exclude lists in the original list-files.sh.
var commonExcludeDirNames = []string{
	"node_modules",
	".git",
	"dist",
	"build",
	"target",
	".next",
	".nuxt",
	"coverage",
	".pytest_cache",
	"__pycache__",
	".venv",
	"vendor",
	".tox",
	".mypy_cache",
	".ruff_cache",
	".turbo",
	"out",
	".parcel-cache",
	".terraform",
}

// homeExcludeDirNames are directories excluded only when listing from $HOME.
var homeExcludeDirNames = []string{
	"Applications",
	"Library",
	".pyenv",
	".jenv",
	".nvm",
	"go",
	"venvs",
	".cursor",
	".docker",
	".vscode",
	".cache",
	".gradle",
	".zsh_sessions",
}
