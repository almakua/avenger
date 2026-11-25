# Avenger

A small, fast, native macOS text editor written entirely in AArch64 assembly.

- native AppKit window, tab bar, menus and command palette
- tmux-style tabs and splits driven by a prefix key (`Ctrl-b`)
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
