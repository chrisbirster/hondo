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
  },
});
