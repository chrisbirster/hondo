# Hondo examples

Examples are intentionally layered with the implementation milestones.

- `counter/` starts as a Solid 2 signal-only compile target in M0.
- M1 turns it into the first `@solidjs/universal` Hondo host-tree example.
- M2 renders the same logical app through the Zig terminal engine.

Examples must not import DOM APIs, `solid-js/web`, browser globals, or a WebView runtime.
