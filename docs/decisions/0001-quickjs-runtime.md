# ADR 0001: QuickJS runtime

- Status: accepted
- Date: 2026-08-29
- Engine: official QuickJS `2026-06-04`

## Decision

Hondo uses the official QuickJS `2026-06-04` release as its JavaScript runtime.

Pin:

```text
https://bellard.org/quickjs/quickjs-2026-06-04.tar.xz
SHA-256: b376e839b322978313d929fd20663b11ba58b75df5a46c126dd19ea2fa70ad2a
```

Hondo does not expose a public multi-engine abstraction. Application code targets Solid 2 + Hondo; QuickJS is an implementation detail behind the Zig runtime boundary.

## Runtime boundary

```text
Solid 2 application
        ↓
@solidjs/universal
        ↓
@hondo/solid
        ↓
Hondo host mutations
        ↓
official QuickJS 2026-06-04
        ↓
Zig runtime / terminal engine
```

QuickJS owns JavaScript execution only. It does not own terminal raw mode, input decoding, layout, the cell grid, terminal output, PTYs, editor buffers, Tree-sitter, LSP, or other native application state.

## Dependency strategy

The release archive and checksum are the source of truth. Hondo will not track QuickJS `master` implicitly and will not vendor an unversioned engine snapshot.

The build/runtime integration may cache the verified upstream source outside the repository, but any automated fetch must verify the SHA-256 above before compilation. QuickJS is compiled as native code and linked into the Hondo/Zig runtime through its public C API.

Engine-specific `JSRuntime`, `JSContext`, and `JSValue` details remain inside the runtime adapter and must not leak into public Hondo component or host-node APIs.

## Why this engine

- small, embeddable C API that fits a Zig-owned runtime;
- current official release supports the ECMAScript features required by Solid 2;
- no C++/JSI layer is required;
- the same release has already demonstrated Solid 2 fine-grained renderer semantics in a separate native-runtime implementation;
- Hondo needs one dependable engine, not a permanent engine bake-off.

## Upgrade policy

A QuickJS upgrade is an explicit dependency change. It must update the pin/checksum, pass Hondo's JavaScript semantics and renderer tests, and pass cross-platform Zig builds before merging to `dev`.
