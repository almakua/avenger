# AGENTS.md

Guide for agents working on Avenger: a native macOS text editor written entirely in
AArch64 assembly. Read this first, then the module you are about to touch.

## Goals

- lightweight and fast: small binary (~154 KB today, `__TEXT` grows in 16 KB pages),
  instant startup, no runtime deps beyond AppKit/CoreText/libSystem
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
- `AV_TYPE=...` sends synthetic keys to the first responder (pane, palette or find field):
  printable ASCII, `\n`, `\b`, `0x1c..0x1f` arrows, `0x1a` undo, `0x01` select all,
  `0x14` next theme, `0x13` Ctrl-s (prefix), `0x10` runs the run loop for 0.5 s (lets
  terminal output, deferred closes and the 300 ms YAML check happen); arrows after the
  prefix cannot be sent (bind actions to letters in a scratch config to test them), and
  composed input is tested by calling the NSTextInputClient methods from a temporary hook
- `AV_BENCH=N` renders the focused pane offscreen N times still and N times scrolling one row
  per frame, then prints µs/frame and the time from `main` to the first frame on stderr
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
  indices that may be -1 (use signed conditions), `ccmp` immediates are 0..31, stack
  scratch slots placed over the saved registers of the same frame, helpers reading the
  caller's frame (pass values in registers instead), make skipping a rebuild when a
  source and its object share the same second (delete the object), views not clipping
  to their bounds since macOS 14 (clip in drawRect), removing a text field from inside
  its own delegate callback (defer with `dispatch_async_f` on the main queue)

## Architecture

| module | role |
|---|---|
| `main.s` | startup: app, render, editor class, config, window, one tab per argv, dev hooks |
| `app.s` | NSApplication, delegate (actions, quit/close confirmation, reload on activate), menus |
| `window.s` | window, theme styling, `av_theme_apply`, `av_config_apply`, reload-if-changed |
| `tabs.s` | tab model (a pane tree per tab, focus, zoom), AvPanes container (layout with the find bar slot, divider hit/drag, cursor rects), tab bar view (click, `×` or middle click closes, `+`), `av_action` dispatch, prefix handling, open/save panels, alerts, Open Config with embedded template |
| `pane.s` | pane tree: leaves and row/column splits, layout into rects, directional neighbour, next leaf, resize/drag ratios, divider hits, node free list |
| `termview.s` | AvTermView: pty read source (CFFileDescriptor), cell drawing, keys to xterm sequences, scrollback view, selection, copy/paste |
| `palette.s` | command palette (AvPalette: actions and tabs, fuzzy filtered, NSTextField delegate), shared themed field/color helpers |
| `findbar.s` | find bar under the focused editor pane (AvFindBar: incremental search, next/prev, replace one/all, count), pattern shared with `render.s` for highlights |
| `lint.s` | YAML validation while typing: debounce timer on the main queue, parse of a text copy on a global queue, first error stored in the Doc (generation checked) |
| `textinput.s` | NSTextInputClient for AvEditorView: marked text kept outside the buffer (drawn by `render.s` at the cursor), commit with optional replacement range, UTF-16 ranges relative to the cursor line, candidate window rect |
| `editorview.s` | AvEditorView: keys (text through `inputContext`), mouse, scroll by visual rows, cursor reveal, clipboard, undo/redo hooks, redraw of sibling panes and YAML check scheduling |
| `render.s` | font metrics, typeset line cache (CTLines by hash of bytes and attributes, flushed with the attributes), drawRect over wrapped visual rows (gutter, current line, indent guides, selection, find matches, color runs cut at row ends, YAML error squiggle and message, cursor), `av_fill`, `av_draw_text` |
| `snapshot.s` | dev hooks AV_SNAPSHOT / AV_TYPE / AV_BENCH |
| `alloc.s` | page and arena allocators |
| `buffer.s` | gap buffer, incremental line index, NEON newline scan, UTF-8 stepping |
| `file.s` | single-read load, atomic save (temp + rename, keeps mode) |
| `doc.s` | Doc = buffer + undo log (merged typing/deleting, joined steps) + highlight hooks; attached Views are shifted on every edit so split panes keep their cursors |
| `edit.s` | View ops: insert/delete/newline+autoindent/soft tab, moves (up/down by visual rows), selections, columns, word wrap rows, `_av_tab_width` |
| `theme.s` | 4 Catppuccin palettes, 32 color roles, YAML themes (base/palette/colors), names |
| `yaml.s` | YAML subset parser (block/flow, quoted/plain multi-line, block scalars, multi-doc, anchors/tags), errors with line numbers, accessors |
| `config.s` | config.yaml load/parse/defaults, paths, mtime change detection, stderr reporting |
| `hl.s` | lexers (generic table-driven for C/JSON/shell/Python, dedicated YAML/asm/Markdown), per-line state cache, language detection |
| `keymap.s` | key spec parser (`C-s`, `M-x`, `D-t`, names) and formatter, prefix bindings table, action names |
| `outline.s` | YAML outline (key and item paths with lines, all documents), Helm/Jinja template detection |
| `search.s` | buffer search forward/backward without moving the gap (memmem on each side, folding loop for smart case), count, replace all as one undo step, fuzzy score |
| `vt.s` | terminal emulator: VT100/xterm subset parser, row-pointer grids (main/alt), scrollback ring recycling rows, replies (DA/DSR) |
| `pty.s` | forkpty + login shell in a given directory (env prepared before fork), resize, write with backpressure, busy check, foreground job cwd, reaping |

Core modules (no AppKit, linked into tests): alloc buffer file doc edit theme yaml
config hl keymap vt pty pane search outline. Tests live in `tests/test_*.s` using
`tests/harness.inc`.

Key data layouts: `include/buffer.inc` (Buffer), `include/doc.inc` (Doc, View, undo
record, move commands, generation and YAML error fields, `WRAP_MAX`), `include/theme.inc`
(color slots), `include/yaml.inc` (nodes, errors), `include/hl.inc` (languages, runs),
`include/keymap.inc` (actions, modifiers), `include/vt.inc` (Vt header, modes, cell bits
and color encoding), `include/pane.inc` (pane nodes, kinds, directions).

## Done (steps 1-13)

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
10. command palette (`:` / ⇧⌘P) over actions and tabs; find bar (`/` / ⌘F) with smart
   case, highlights and count, replace (`?` / ⌥⌘F) one or all
11. word wrap to the pane width (`wrap`, `C-s w`, scroll offset = line + fraction of its
   rows), indent guides from enclosing blocks (`indent_guides`), YAML validation in the
   background with squiggle and inline message, outline palette over key paths (`C-s g`)
12. performance: CTLine cache in `av_draw_text` (dense asm 1.05 to 0.72 ms per still frame,
   scrolling 0.84 to 0.48 ms), `AV_BENCH` hook, only `_main` exported (-11 KB); startup is
   ~85 ms from `main`, of which AppKit app and window setup take all but ~2 ms
13. composed input in editors (NSTextInputClient): text keys go through `inputContext`, dead
   keys and IMEs show marked text underlined at the cursor, the accent menu replaces the
   previous letter, a click commits; middle click on a tab closes it

Verified numbers: 592 unit checks passing; ~0.7 ms per offscreen frame of a full window
of dense asm; an 11 MB YAML opens in ~90 ms and a 100 MB one draws in ~0.14 s; full
highlight state for 1.5M lines in ~79 ms; parser run on ~3000 real YAML files with no
crashes (remaining failures are Helm/Jinja templates or genuinely invalid files); nvim and
zsh with plugins and ls colors render correctly in a terminal pane. Checked by hand by the
maintainer: trackpad scrolling, divider drag (also with wrapped text), click to focus,
palette arrows and clicks, find bar shift/option return.

## Next steps

Candidates, to be agreed with the maintainer: terminal mouse reporting and bold/italic
faces, persisting the theme picked from the menu, config errors shown in the UI, dragging
tabs to reorder them

## Known limitations

- composed input works in editors only (terminals take the characters of each key as is);
  input methods see the cursor line as their whole context
- wide glyphs (CJK/emoji) and CRLF line endings misalign the cursor column
- lines longer than 8 KB are truncated for display and highlighting; wrapped rows are not
  indented like their line, and indent guides cover only a line's first row
- YAML validation shows the parser's first error only; the outline needs a document that parses
- no cursor blink; undo back to the saved state keeps the dirty flag
- theme picked from the menu and `C-s w` are session-only (persist them in config.yaml)
- config errors are reported on stderr plus a beep on reload, not yet in the UI
- tabs cannot be reordered by dragging; panes cannot be swapped or moved to another tab
- find/replace is plain text (no regex), not available in terminal scrollback; palette and
  find bar keep the colors of the theme they were opened with
- prefix bindings do not repeat (tmux `-r`), each resize step needs the prefix again
- terminal: no mouse reporting (1000/1006), no bold/italic font faces (bold brightens
  colors 0..7), wide glyphs take one cell, no reflow on resize, tab stops fixed at 8,
  shell is always the login shell (no `shell:` option yet), cursor shape requests
  (DECSCUSR) are ignored
