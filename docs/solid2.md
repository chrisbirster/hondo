# Solid 2 baseline

Hondo targets **Solid 2 only**.

The authoritative documentation baseline is:

- https://v2.solidjs.com

Hondo does not target Solid 1.x compatibility and must not use the Solid 1.x `solid-js/universal` subpath. Solid 2 publishes the custom-renderer primitive as the separate `@solidjs/universal` package.

## Initial coordinated RC baseline

The M0/M1 foundation starts from:

```text
solid-js             2.0.0-rc.1
@solidjs/universal   2.0.0-rc.0
```

These versions should be treated as a coordinated Solid 2 RC baseline rather than independently floated dependencies. When the Solid 2 RC train advances, update and validate the pair together against Hondo's renderer conformance tests.

## Rules

- Do not add Solid 1.x compatibility shims.
- Do not import the Solid 1.x `solid-js/universal` entrypoint.
- Use `@solidjs/universal` for Hondo's renderer.
- Follow `v2.solidjs.com` semantics for components, control flow, reactivity, rendering, and migration decisions.
- Pin RC versions during pre-alpha development so upstream changes cannot silently alter renderer semantics.
- Upgrading the Solid RC baseline requires renderer tests to pass before merging to `dev`.

Solid's DOM/web renderer is not part of Hondo's runtime architecture.
