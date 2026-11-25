# AGENTS.md

Guide for agents working on Avenger: a native macOS text editor written entirely in
AArch64 assembly. Read this first, then the module you are about to touch.

## Goals

- lightweight and fast: small binary (~148 KB today), instant startup, no runtime deps
  beyond AppKit/CoreText/libSystem
- native AppKit GUI plus tmux-style tabs and panes driven by a prefix key (default `C-s`)
- themes (Catppuccin Mocha default), syntax highlighting, YAML as config format and as a
  first-class edited language
- repo stays local for now (the GitLab project is created by hand later), no CI

## Working agreements

- never run `git commit`; stage only when asked and hand back a terse commit message
  (`feat|fix|chore|docs|refactor|test|style: subject`, no scope, no AI attribution)
- work one step at a time: say what the step does and which files it touches, then recap
  and propose the commit message
- chat with the maintainer in Italian; everything in the repo is English
- comments: max 2 lines, lowercase start, no trailing period, only the essential why,
  sentences joined with commas or semicolons (no " - " separators)

## Build, run, test

```sh
make                 # build/Avenger.app (clang as assembler/linker driver, CLT only)
make run             # open the app
make test            # CLI unit tests for the AppKit-free modules
make yamlcheck       # build/yamlcheck file.yaml ...
make size | make clean
build/Avenger.app/Contents/MacOS/avenger [files...]
```

Dev hooks (no screen-recording rights needed for visual checks):

- `AV_SNAPSHOT=out.png` renders the window content to a PNG after startup and exits
- `AV_TYPE=...` sends synthetic keys to the first responder (pane, palette or find field): printable ASCII, `\n`,
  `\b`, `0x1c..0x1f` arrows, `0x1a` undo, `0x01` select all, `0x14` next theme,
  `0x13` Ctrl-s (prefix), `0x10` runs the run loop for 0.5 s (lets terminal output arrive)
- `AVENGER_CONFIG_DIR=dir` uses `dir/config.yaml` and `dir/themes/` instead of
  `~/.config/avenger`

## Assembly conventions

- Apple `as` syntax, arm64 only, macOS 13+; one module per `src/*.s`, shared offsets and
  macros in `include/*.inc`
- public functions use the C ABI, prefixed `_av_`, declared with `FUNC_BEGIN`; local
  helpers are `L` labels; frames save exactly the callee-saved registers they use
- ObjC through `objc_msgSend` with macros from `include/objc.inc`: `SELDEF`/`CLASSREF`/
  `CFSTRDEF` emit `__objc_selrefs`/`__objc_classrefs`/`__cfstring` like clang (dyld fixes
  them up, zero runtime lookup); `MSG sel` sends to `x0` with args already in `x2..x7`/
  `d0..d7`; NSRect/NSPoint are HFAs in `d0..d3`
- constant CFStrings must be ASCII; build non-ASCII NSStrings with `stringWithUTF8String:`
- variadic C calls (`printf`, `dprintf`, `open` with mode) pass varargs on the stack;
  non-variadic stack args (e.g. NSEvent `isARepeat`/`keyCode`) use natural alignment
- runtime classes are built with `objc_allocateClassPair` + `class_addMethod`
  (AvAppDelegate, AvEditorView/AvTermView with an `st` ivar holding their state, AvTabBar,
  AvPanes: the flipped content view that lays out panes and drags dividers)
- memory: `av_pages_*` (mmap) for growable blocks, `av_arena_alloc` for small long-lived
  objects (never freed)
- pitfalls already hit: a macro whose destination register aliases its index register
  (`CH w11, x11`), overwriting an argument before reading it, unsigned compares on
  indices that may be -1 (use signed conditions), `ccmp` immediates are 0..31,
  make skipping a rebuild when a source and its object share the same second (delete the object),
  views not clipping to their bounds since macOS 14 (clip in drawRect)

## Architecture

| module | role |
|---|---|
| `main.s` | startup: app, render, editor class, config, window, one tab per argv, dev hooks |
| `app.s` | NSApplication, delegate (actions, quit/close confirmation, reload on activate), menus |
| `window.s` | window, theme styling, `av_theme_apply`, `av_config_apply`, reload-if-changed |
| `tabs.s` | tab model (a pane tree per tab, focus, zoom), AvPanes container (layout, divider hit/drag, cursor rects), tab bar view, `av_action` dispatch, prefix handling, open/save panels, alerts, Open Config with embedded template |
| `pane.s` | pane tree: leaves and row/column splits, layout into rects, directional neighbour, next leaf, resize/drag ratios, divider hits, node free list |
| `termview.s` | AvTermView: pty read source (CFFileDescriptor), cell drawing, keys to xterm sequences, scrollback view, selection, copy/paste |
| `palette.s` | command palette (AvPalette: actions and tabs, fuzzy filtered, NSTextField delegate), shared themed field/color helpers |
| `findbar.s` | find bar under the focused editor pane (AvFindBar: incremental search, next/prev, replace one/all, count), pattern shared with `render.s` for highlights |
| `editorview.s` | AvEditorView: keys, mouse, scroll, clipboard, undo/redo hooks |
| `render.s` | font metrics, drawRect (gutter, current line, selection, color runs, cursor), `av_fill`, `av_draw_text` |
| `snapshot.s` | dev hooks AV_SNAPSHOT / AV_TYPE |
| `alloc.s` | page and arena allocators |
| `buffer.s` | gap buffer, incremental line index, NEON newline scan, UTF-8 stepping |
| `file.s` | single-read load, atomic save (temp + rename, keeps mode) |
| `doc.s` | Doc = buffer + undo log (merged typing/deleting, joined steps) + highlight hooks; attached Views are shifted on every edit so split panes keep their cursors |
| `edit.s` | View ops: insert/delete/newline+autoindent/soft tab, moves, selections, columns, `_av_tab_width` |
| `theme.s` | 4 Catppuccin palettes, 32 color roles, YAML themes (base/palette/colors), names |
| `yaml.s` | YAML subset parser (block/flow, quoted/plain multi-line, block scalars, multi-doc, anchors/tags), errors with line numbers, accessors |
| `config.s` | config.yaml load/parse/defaults, paths, mtime change detection, stderr reporting |
| `hl.s` | lexers (generic table-driven for C/JSON/shell/Python, dedicated YAML/asm/Markdown), per-line state cache, language detection |
| `keymap.s` | key spec parser (`C-s`, `M-x`, `D-t`, names) and formatter, prefix bindings table, action names |
| `search.s` | buffer search forward/backward without moving the gap (memmem on each side, folding loop for smart case), count, replace all as one undo step, fuzzy score |
| `vt.s` | terminal emulator: VT100/xterm subset parser, row-pointer grids (main/alt), scrollback ring recycling rows, replies (DA/DSR) |
| `pty.s` | forkpty + login shell in a given directory (env prepared before fork), resize, write with backpressure, busy check, foreground job cwd, reaping |

Core modules (no AppKit, linked into tests): alloc buffer file doc edit theme yaml
config hl keymap vt pty pane search. Tests live in `tests/test_*.s` using `tests/harness.inc`.

Key data layouts: `include/buffer.inc` (Buffer), `include/doc.inc` (Doc, View, undo
record, move commands), `include/theme.inc` (color slots), `include/yaml.inc` (nodes,
errors), `include/hl.inc` (languages, runs), `include/keymap.inc` (actions, modifiers),
`include/vt.inc` (Vt header, modes, cell bits and color encoding), `include/pane.inc` (pane
nodes, kinds, directions).

## Done (steps 1-10)

1. scaffold: Makefile, Info.plist, objc macros, themed empty window
2. allocators, gap buffer with line index, file load/atomic save, test harness
3. editor view: CoreText drawing, cursor, typing, selection, scrolling, clipboard, undo/redo
4. theme engine: built-in Catppuccin flavors, View > Theme menu, ⌥⌘T
5. YAML parser, `config.yaml` (font, font_size, theme, tab_width, prefix, keys), YAML
   themes, reload on save/activation, `yamlcheck`
6. syntax highlighting for YAML, ARM64 asm, C/ObjC/C++, JSON, shell, Python, Markdown
7. tabs: tab bar, actions, prefix keymap (default `C-s`, configurable), open/save panels,
   unsaved-changes prompts, Open Config with template
8. terminal tabs: `vt.s` emulator (CSI cursor/erase/insert/delete, SGR 16/256/truecolor
   as rgb555, scroll regions, alt screen 47/1047/1049, DEC line drawing, OSC titles,
   bracketed paste, DA/DSR replies), `pty.s` login shell, AvTermView with scrollback
   (3000 lines), selection and copy/paste; 16 `ansi_*` theme roles; prefix `t` / ⇧⌘T
9. panes: `pane.s` tree per tab, splits (`%` `"` same content, `|` `-` terminal), focus by
   direction/next/click, zoom, resize by keys or divider drag; editor splits share the Doc
   (views attached to it), terminal splits start in the job's or the file's directory
10. command palette (`:` / ⇧⌘P) over actions and tabs; find bar (`/` / ⌘F) with smart case,
   highlights and count, replace (`?` / ⌥⌘F) one or all

Verified numbers: 561 unit checks passing (nvim, zsh with plugins and ls colors render
correctly in a terminal tab); 100 MB YAML opens and draws in ~0.14 s; full
highlight state for 1.5M lines in ~79 ms; parser run on ~3000 real YAML files with no
crashes (remaining failures are Helm/Jinja templates or genuinely invalid files).

## Next steps

11. YAML editing extras: inline validation markers from `yaml.s` errors (skip Helm/Jinja
    templates), indent guides (`T_INDENT`), outline panel jumping via `N_LINE`
12. performance pass: per-line render cache instead of one CTLine per run per frame,
    startup profiling, binary size

## Known limitations

- no NSTextInputClient yet: dead keys and IME input do not compose
- wide glyphs (CJK/emoji) and CRLF line endings misalign the cursor column
- lines longer than 8 KB are truncated for display and highlighting
- no cursor blink; undo back to the saved state keeps the dirty flag
- theme picked from the menu is session-only (persist it in config.yaml)
- config errors are reported on stderr plus a beep on reload, not yet in the UI
- tabs cannot be reordered by dragging; panes cannot be swapped or moved to another tab
- find/replace is plain text (no regex), not available in terminal scrollback; palette and
  find bar keep the colors of the theme they were opened with
- prefix bindings do not repeat (tmux `-r`), each resize step needs the prefix again
- terminal: no mouse reporting (1000/1006), no bold/italic font faces (bold brightens
  colors 0..7), wide glyphs take one cell, no reflow on resize, tab stops fixed at 8,
  shell is always the login shell (no `shell:` option yet), cursor does not change
  shape or show focus
