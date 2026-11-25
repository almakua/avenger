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

## Layout

```
include/   assembler macros (objc runtime, constants)
src/       editor sources, one .s per module
```

ObjC is called directly through `objc_msgSend`; selectors and class references are
emitted in `__objc_selrefs` / `__objc_classrefs` like clang does, so dyld fixes them
up at load time with no runtime lookup.
