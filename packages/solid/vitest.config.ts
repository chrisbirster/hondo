import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Hondo is a client-side native terminal runtime. Node is only the test
  // process; resolving Solid's `node` export would select the SSR build, where
  // imperative signal setters are intentionally inert.
  resolve: {
    conditions: ['browser', 'development'],
  },
  test: {
    environment: 'node',
    server: {
      deps: {
        // node_modules are externalized by Vitest by default, which lets Node's
        // native resolver select Solid's `node`/SSR condition before Vite can
        // apply Hondo's client conditions. Inline the Solid runtime family so
        // the Vite module runner resolves the same client build QuickJS will use.
        inline: [/solid-js/, /@solidjs\//],
      },
    },
  },
});
