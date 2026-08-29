# Hondo

**Terminal-native SolidJS.**  
*A most profitable arrangement.*

Hondo is an independent framework for building native terminal interfaces with SolidJS. It combines Solid 2 fine-grained reactivity and `@solidjs/universal` with a Zig terminal host and renderer.

Hondo is not part of StingJS. It borrows the proven custom-renderer model while defining a terminal-specific host, component system, layout engine, cell grid, and input stack.

## Principles

- Terminal-native: no DOM, browser, WebView, or CSS engine is required at runtime.
- Solid owns reactive UI composition; Zig owns terminal mechanics and rendering.
- QuickJS executes Solid/Hondo application code, not performance-critical native editor loops.
- Hondo stays general-purpose and must not depend on Zim.
- Heavy native views can bypass JavaScript for their hot paths.
- Styling remains an explicit experiment until a terminal-native model is proven.

## Architecture

```text
Solid 2 / JSX
      |
@solidjs/universal
      |
 Hondo host tree
      |
 QuickJS <-> Zig host bridge
      |
 layout + scene tree
      |
   cell grid
      |
 terminal diff / ANSI
```

See [`docs/architecture.md`](docs/architecture.md), [`docs/roadmap.md`](docs/roadmap.md), and [`docs/development.md`](docs/development.md).

## Flagship consumer

Zim is intended to become Hondo's demanding first real-world consumer while remaining a separate repository and product. Hondo itself must remain useful for unrelated terminal applications.

## Status

Pre-alpha. The initial work is focused on proving the Solid -> `@solidjs/universal` -> QuickJS -> Zig -> terminal vertical slice.
