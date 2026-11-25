# AGENTS.md

Guide for agents working on Avenger: a native macOS text editor written entirely in
AArch64 assembly. Read this first, then the module you are about to touch.

## Goals

- lightweight and fast: small binary (~113 KB today), instant startup, no runtime deps
  beyond AppKit/CoreText/libSystem
- native AppKit GUI plus tmux-style tabs/splits driven by a prefix key (default `C-s`)
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
- `AV_TYPE=...` sends synthetic keys to the active tab first: printable ASCII, `\n`,
  `\b`, `0x1c..0x1f` arrows, `0x1a` undo, `0x01` select all, `0x14` next theme,
  `0x13` Ctrl-s (prefix)
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
  (AvAppDelegate, AvEditorView with an `st` ivar holding the View state, AvTabBar)
- memory: `av_pages_*` (mmap) for growable blocks, `av_arena_alloc` for small long-lived
  objects (never freed)
- pitfalls already hit: a macro whose destination register aliases its index register
  (`CH w11, x11`), overwriting an argument before reading it, unsigned compares on
  indices that may be -1 (use signed conditions), `ccmp` immediates are 0..31

## Architecture

| module | role |
|---|---|
| `main.s` | startup: app, render, editor class, config, window, one tab per argv, dev hooks |
| `app.s` | NSApplication, delegate (actions, quit/close confirmation, reload on activate), menus |
| `window.s` | window, theme styling, `av_theme_apply`, `av_config_apply`, reload-if-changed |
| `tabs.s` | tab model, container view, tab bar view, `av_action` dispatch, prefix handling, open/save panels, alerts, Open Config with embedded template |
| `editorview.s` | AvEditorView: keys, mouse, scroll, clipboard, undo/redo hooks |
| `render.s` | font metrics, drawRect (gutter, current line, selection, color runs, cursor), `av_fill`, `av_draw_text` |
| `snapshot.s` | dev hooks AV_SNAPSHOT / AV_TYPE |
| `alloc.s` | page and arena allocators |
| `buffer.s` | gap buffer, incremental line index, NEON newline scan, UTF-8 stepping |
| `file.s` | single-read load, atomic save (temp + rename, keeps mode) |
| `doc.s` | Doc = buffer + undo log (merged typing/deleting, joined steps) + highlight hooks |
| `edit.s` | View ops: insert/delete/newline+autoindent/soft tab, moves, selections, columns, `_av_tab_width` |
| `theme.s` | 4 Catppuccin palettes, 32 color roles, YAML themes (base/palette/colors), names |
| `yaml.s` | YAML subset parser (block/flow, quoted/plain multi-line, block scalars, multi-doc, anchors/tags), errors with line numbers, accessors |
| `config.s` | config.yaml load/parse/defaults, paths, mtime change detection, stderr reporting |
| `hl.s` | lexers (generic table-driven for C/JSON/shell/Python, dedicated YAML/asm/Markdown), per-line state cache, language detection |
| `keymap.s` | key spec parser (`C-s`, `M-x`, `D-t`, names), prefix bindings table, action names |

Core modules (no AppKit, linked into tests): alloc buffer file doc edit theme yaml
config hl keymap. Tests live in `tests/test_*.s` using `tests/harness.inc`.

Key data layouts: `include/buffer.inc` (Buffer), `include/doc.inc` (Doc, View, undo
record, move commands), `include/theme.inc` (color slots), `include/yaml.inc` (nodes,
errors), `include/hl.inc` (languages, runs), `include/keymap.inc` (actions, modifiers).

## Done (steps 1-7)

1. scaffold: Makefile, Info.plist, objc macros, themed empty window
2. allocators, gap buffer with line index, file load/atomic save, test harness
3. editor view: CoreText drawing, cursor, typing, selection, scrolling, clipboard, undo/redo
4. theme engine: built-in Catppuccin flavors, View > Theme menu, ⌥⌘T
5. YAML parser, `config.yaml` (font, font_size, theme, tab_width, prefix, keys), YAML
   themes, reload on save/activation, `yamlcheck`
6. syntax highlighting for YAML, ARM64 asm, C/ObjC/C++, JSON, shell, Python, Markdown
7. tabs: tab bar, actions, prefix keymap (default `C-s`, configurable), open/save panels,
   unsaved-changes prompts, Open Config with template

Verified numbers: 357 unit checks passing; 100 MB YAML opens and draws in ~0.14 s; full
highlight state for 1.5M lines in ~79 ms; parser run on ~3000 real YAML files with no
crashes (remaining failures are Helm/Jinja templates or genuinely invalid files).

## Next steps

8. terminal tabs: `forkpty` + login shell, VT100/xterm subset parser (CSI cursor/erase,
   SGR colors mapped to theme, alternate screen, scroll regions), cell grid + scrollback,
   rendering via `av_draw_text`, keys forwarded except the prefix; tab kind
   `TAB_KIND_TERMINAL`, new action + prefix key to open one
9. pane splits (binary pane tree, focus, resize, zoom) for editors and terminals
10. command palette (all actions by name via `av_action_name`) + find/replace
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
- tabs cannot be reordered by dragging
