# Hondo roadmap

Hondo follows a milestone train from pre-alpha foundation to a first usable `v0.1.0`.

## M0 — Foundation

Target: `v0.1.0-alpha.1`

Goal: establish Hondo as an independent Solid terminal project.

Tasks:

- [ ] monorepo/workspace layout
- [ ] Zig 0.16 build foundation
- [ ] TypeScript/Solid workspace
- [ ] pin supported Node/pnpm versions
- [ ] Solid 2 dependency
- [ ] `@solidjs/universal` dependency
- [ ] QuickJS dependency strategy
- [ ] JS/Zig ownership contract
- [ ] Linux/macOS/Windows CI
- [ ] Zig tests and formatting
- [ ] TypeScript tests, typecheck, and formatting
- [ ] examples skeleton
- [ ] license decision before the first public release

Exit: the repository builds and tests on all three desktop OSes and the runtime boundaries are explicit.

## M1 — Solid to Zig vertical slice

Target: `v0.1.0-alpha.2`

Goal: prove Solid 2 -> `@solidjs/universal` -> QuickJS -> Zig.

Tasks:

- [ ] embed QuickJS
- [ ] load bundled Solid application code
- [ ] implement Hondo host-node identity/tree
- [ ] implement universal renderer host operations
- [ ] define compact JS/Zig mutation protocol
- [ ] implement Zig scene tree
- [ ] Solid signal update reaches Zig
- [ ] Zig input event reaches a Solid callback
- [ ] deterministic disposal/cleanup
- [ ] host-tree lifecycle tests
- [ ] counter example

Exit: a terminal input event changes a Solid signal and only the affected text host node is mutated.

## M2 — Native terminal engine

Target: `v0.1.0-alpha.3`

Goal: make Hondo a real terminal runtime.

Tasks:

- [ ] raw mode
- [ ] guaranteed restoration
- [ ] alternate screen
- [ ] keyboard decoding
- [ ] resize events
- [ ] Unicode/grapheme foundation
- [ ] terminal capability detection
- [ ] color support
- [ ] mouse foundation
- [ ] cell representation
- [ ] current/previous cell grids
- [ ] cell-grid diff
- [ ] minimal ANSI writer
- [ ] clipping
- [ ] invalidation
- [ ] focus model
- [ ] Linux/macOS/Windows terminal tests

Exit: Hondo safely enters a terminal UI, reacts to input/resize, renders incremental cell changes, and restores the terminal on exit.

## M3 — Layout and primitive components

Target: `v0.1.0-beta.1`

Goal: make Hondo useful for ordinary terminal applications.

Tasks:

- [ ] `Text`
- [ ] `Box`
- [ ] `Stack`
- [ ] `Row`
- [ ] `Column`
- [ ] `Spacer`
- [ ] width/height/min/max sizing
- [ ] grow/shrink behavior
- [ ] row/column layout
- [ ] padding and gap
- [ ] alignment
- [ ] clipping
- [ ] foreground/background colors
- [ ] bold/italic/underline/dim/inverse
- [ ] refs
- [ ] keyboard focus
- [ ] event propagation
- [ ] snapshots/examples

Exit: a useful small dashboard can be written entirely as Solid/Hondo components.

## M4 — Styling decision

Target: `v0.1.0-beta.*`

Goal: choose a terminal-native styling model from evidence.

Spikes:

- [ ] StyleX authoring adapter without a CSS runtime
- [ ] modifier-composition model
- [ ] Hondo-native typed style-object model

Evaluate:

- [ ] TypeScript ergonomics
- [ ] static extraction potential
- [ ] dynamic/reactive styles
- [ ] serialization cost
- [ ] Zig representation
- [ ] themes/tokens
- [ ] variants
- [ ] composability

Invariant: Hondo does not embed a CSS engine.

Exit: one styling model is selected and documented; rejected approaches are recorded with reasons.

## M5 — TUI component library

Target: `v0.1.0-beta.2`

Goal: provide editor-quality reusable terminal controls.

Tasks:

- [ ] `Input`
- [ ] `List`
- [ ] `Menu`
- [ ] `Popup`
- [ ] `Tree`
- [ ] `Table`
- [ ] `Tabs`
- [ ] `ScrollView`
- [ ] keyboard navigation
- [ ] selection
- [ ] scrolling
- [ ] focus traversal
- [ ] overlays/z-order
- [ ] popup positioning
- [ ] text editing for `Input`
- [ ] mouse interactions where appropriate

Exit: developers can build a useful non-Zim TUI without writing native Zig controls.

## M6 — NativeView

Target: `v0.1.0-rc.1`

Goal: support heavyweight Zig-native regions embedded in a Solid/Hondo UI.

Tasks:

- [ ] native component registration
- [ ] native measurement
- [ ] layout bounds/constraints
- [ ] paint callback
- [ ] native invalidation
- [ ] focus handoff
- [ ] direct input routing
- [ ] lifecycle ownership
- [ ] native -> Solid state notifications
- [ ] Solid -> native property changes
- [ ] performance benchmarks

Exit: a focused native view can process input and paint entirely in Zig while participating in a Hondo layout.

## M7 — Zim integration

Target: integration milestone; most work occurs in the Zim repository.

Goal: prove Hondo as the reactive application UI for a real terminal-first editor while keeping Zim's editing hot path native.

Tasks:

- [ ] Zim consumes Hondo as an external dependency
- [ ] Hondo renders Zim application chrome
- [ ] Zim native `EditorView` embeds through NativeView
- [ ] editor input bypasses QuickJS/Solid
- [ ] status/command/popup UI reacts through Solid
- [ ] integration performance tests
- [ ] headless/editor tests remain independent of Hondo

Exit: Zim can be edited interactively with Hondo UI around a Zig-native editor viewport.

## M8 — Hondo v0.1.0

Target: `v0.1.0`

Release criteria:

- [ ] Solid 2 integration
- [ ] `@solidjs/universal` renderer
- [ ] QuickJS runtime
- [ ] Zig terminal renderer
- [ ] terminal input/output lifecycle
- [ ] cell-grid diffing
- [ ] cross-platform CI
- [ ] primitive/component library
- [ ] documented styling model
- [ ] NativeView API
- [ ] independent examples
- [ ] Zim integration proof
- [ ] documented public API

## Release train

```text
M0   -> v0.1.0-alpha.1
M1   -> v0.1.0-alpha.2
M2   -> v0.1.0-alpha.3
M3   -> v0.1.0-beta.1
M4/5 -> v0.1.0-beta.2
M6   -> v0.1.0-rc.1
M7/8 -> v0.1.0
```

After `v0.1.0`, Hondo follows Semantic Versioning. During `0.x`, breaking API evolution is expected and must be called out explicitly in release notes.
