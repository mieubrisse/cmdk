cmdk
====

![](./testimony.png)

The ⌘-k "access anything" shortcut is awesome on Notion, Slack, etc.

The terminal, by comparison, is a dinosaur: tons of repeated `cd` and `ls` and `TAB` just to get anywhere.

This is ⌘-k for the terminal: access anything on your filesystem, from anywhere, with previews before you open:

![](./demo.png)

![](./demo2.png)

When you press enter, selected files are identified by type and opened accordingly:

- Directories get `cd`d to
- Text files get opened in your [`$EDITOR`](https://bash.cyberciti.biz/guide/$EDITOR_variable) (or `vim -O` if unset)
- Images and PDFs get opened in the Preview app
- `.key` files get opened in Keynote

> **Note:** cmdk is currently macOS-focused. File opening (Preview, Keynote, `open` command) assumes macOS. The core navigation works on Linux, but file-open behavior may vary.

_I'm extremely grateful to [fzf](https://github.com/junegunn/fzf); this project wouldn't be possible without it. I'd been fed up with terminal navigation for a decade, and fzf was the missing piece needed to make cmdk possible._

Installation
------------
1. Install cmdk:
   ```sh
   brew install mieubrisse/cmdk/cmdk
   ```
   This installs the `cmdk` binary along with its required dependencies (`fzf` and `fd`).

   Optionally, install tools for richer file previews:
   ```sh
   # For previewing text, image, and PDF files respectively
   brew install bat tiv poppler
   ```
2. Source the shell integration. In your `.zshrc` or `.bashrc`:
   ```sh
   eval "$(cmdk init)"
   ```
   Or if you're on `fish`, in your `~/.config/fish/config.fish`:
   ```fish
   cmdk init | source
   ```
3. (Optional) Bind the `⌘-k` hotkey (or any other you prefer) to type `cmdk` + Enter in your terminal:
   <details>
   <summary>iTerm</summary>

   `Settings → Profiles → Keys → Keybindings → + → Send Text`, then bind `⌘-k` to send the text `cmdk\n`

   </details>
   <details>
   <summary>Ghostty</summary>

   ```
   # ~/.config/ghostty/config  (or $XDG_CONFIG_HOME/ghostty/config)
   keybind = cmd+k=text:cmdk\r
   ```

   </details>
4. (Optional) To use cmdk's file listing and previews with fzf's `Ctrl-T`, add to your `.zshrc` or `.bashrc`:
   ```sh
   export FZF_CTRL_T_COMMAND="cmdk list-files"
   export FZF_CTRL_T_OPTS="-m --ansi --scheme=path --preview='cmdk preview {}'"
   ```
   Or in `~/.config/fish/config.fish`:
   ```fish
   set -gx FZF_CTRL_T_COMMAND "cmdk list-files"
   set -gx FZF_CTRL_T_OPTS "-m --ansi --scheme=path --preview='cmdk preview {}'"
   ```
5. Open a new shell and press your hotkey (⌘-K if you bound it) or type `cmdk`

Usage
-----
Press ⌘-k (or type `cmdk`) and...

- Type to start filtering
  > If you're trying to get a directory, add a `/` to the end of your search term. E.g. `down/` will pull up the `Downloads` directory
- `Ctrl-j` and `Ctrl-k` to scroll up and down the results list
- `ENTER` to select the result
- `TAB` to select multiple items before `ENTER`
- `Ctrl-u` to clear the selection

> Some directories like `Library`, `/`, and `.git` are full of stuff you don't typically need to browse, so their contents are excluded. To get into them, first ⌘-k to the directory itself, then ⌘-k again to see its contents.

> Sometimes you only want to navigate within the current directory. Use `cmdk -o` to list **o**nly the current directory's contents (no recursing) or `cmdk -s` to list **s**ubdirectories (recursing). Tip: you can set up separate terminal hotkeys for these — e.g., `⌘-k` for `cmdk\n` and `⌘-shift-k` for `cmdk -s\n`.

### Command-line flags

- `-o` - Only list the contents of the current directory at depth 1
- `-s` - List all contents of the current directory recursively, including subdirectories

Building from source
--------------------
You need Go 1.25+ and the runtime dependencies installed:

```sh
brew install go fzf fd         # required
brew install bat tiv poppler   # optional: text, image, and PDF previews
```

```sh
cd go/
make build    # produces ./cmdk
make clean    # removes the binary
```

Or without Make:
```sh
cd go/
go build -o cmdk .
```

Feedback
--------
I'd love to hear how you're using cmdk, and making it your own.

TODO
----
- [Allow customizing the program used to open files](https://github.com/mieubrisse/cmdk/issues/4)
- [Allow for favoriting files that pop to the top of the search](https://github.com/mieubrisse/cmdk/issues/5)
- [Store the results of a selection in the history](https://github.com/mieubrisse/cmdk/issues/1)
