# Avenger

A small, fast, native macOS text editor written entirely in AArch64 assembly.

- native AppKit window, tab bar, menus and command palette
- tmux-style tabs and panes driven by a prefix key (`Ctrl-s`, configurable)
- themes, Catppuccin Mocha by default
- syntax highlighting, first-class YAML editing
- configuration in YAML (`~/.config/avenger/config.yaml`)

## Requirements

- Apple Silicon Mac, macOS 13+
- Command Line Tools (`xcode-select --install`), no Xcode needed

## Build

```sh
make          # build/Avenger.app
make run      # build and open the app
make size     # binary size and sections
make clean
```

Run from a terminal:

```sh
build/Avenger.app/Contents/MacOS/avenger [file]
```

## Configuration

Copy `config.example.yaml` to `~/.config/avenger/config.yaml` (or set
`AVENGER_CONFIG_DIR`). Keys: `font`, `font_size`, `theme`, `tab_width`, `prefix`, `keys`.
The file is reloaded when you save it from Avenger or switch back to the app; parse
errors are printed to stderr with the line number and the previous config stays active.

Themes: the four Catppuccin flavors are built in (`mocha`, `macchiato`, `frappe`,
`latte`) and can be switched from View > Theme (or ⌥⌘T). Any other `theme:` name loads
`~/.config/avenger/themes/<name>.yaml`, see `themes/example.yaml`.

## Tabs and keys

Every file opens in a tab (`avenger a.yaml b.s` opens two). Tabs are driven from the
tab bar (click, `×` to close, `+` for a new one), the menus, or the prefix key:

| after `Ctrl-s` | action        | menu / direct  |
|----------------|---------------|----------------|
| `c`            | new tab       | ⌘T             |
| `t`            | new terminal  | ⇧⌘T            |
| `&`            | close tab     | ⇧⌘W            |
| `n` / `p`      | next / prev   | ⌥⌘→ / ⌥⌘←      |
| `l`            | last used tab |                |
| `1`..`9`       | go to tab     | ⌘1..⌘9         |
| `f`            | open file     | ⌘O             |
| `,`            | open config   | ⌘,             |
| `s`            | save          | ⌘S             |
| `T`            | next theme    | ⌥⌘T            |

`prefix:` and `keys:` in config.yaml change them; `Esc` cancels a pending prefix and
pressing the prefix twice sends it to the tab.

## Panes

A tab splits into panes, editors and terminals mixed:

| after `Ctrl-s` | action                          | menu / direct |
|----------------|---------------------------------|---------------|
| `%` / `"`      | split right / down              | ⌘D / ⇧⌘D      |
| `\|` / `-`     | terminal right / below          |               |
| arrows         | focus the pane in that direction |              |
| `o`            | next pane                       | ⌘]            |
| `x`            | close pane (the last one closes the tab) | ⌘W   |
| `z`            | zoom the pane to the whole tab  | View menu     |
| `⌥` arrows     | move the nearest divider        | drag it       |

Splitting an editor shows the same file in a second view (edits appear in both, each
keeps its own cursor and scroll); splitting a terminal starts a new shell in the
directory of the running job, and a terminal split from an editor starts in the file's
folder. A click focuses a pane; only the focused one shows a solid cursor.

## Terminal tabs

`Ctrl-s t` opens your login shell in a tab (xterm-256color: colors, alternate screen,
scroll regions, bracketed paste, titles). The wheel scrolls back through 3000 lines
(or sends arrows inside full-screen programs), drag or double/triple click to select,
⌘C/⌘V to copy and paste. ⌥ composes characters as usual, ⌥←/⌥→ and ⌥⌫ work on words.
The pane closes when the shell exits; closing it while a job runs asks first. The 16
terminal colors are theme roles (`ansi_red`, `ansi_bright_black`, ...).

## Syntax highlighting

YAML, ARM64 assembly, C/Objective-C/C++, JSON, shell (also Makefile, Dockerfile, `#!`
scripts), Python and Markdown, detected from the file name. Colors come from the theme
roles (`keyword`, `string`, `key`, ...), so custom themes recolor them too.

## Tools

```sh
make yamlcheck && build/yamlcheck file.yaml ...   # validate YAML with the editor's parser
```

## Layout

```
include/   assembler macros (objc runtime, constants, struct offsets)
src/       editor sources, one .s per module
tests/     unit tests for the AppKit-free modules (make test)
tools/     CLI helpers built on the same modules
themes/    example theme file
```

ObjC is called directly through `objc_msgSend`; selectors and class references are
emitted in `__objc_selrefs` / `__objc_classrefs` like clang does, so dyld fixes them
up at load time with no runtime lookup.
