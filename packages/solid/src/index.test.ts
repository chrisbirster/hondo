import { describe, expect, it } from 'vitest';
import { createSignal } from 'solid-js';
import { solid2Baseline } from './index.js';

describe('Solid 2 baseline', () => {
  it('uses the coordinated Solid 2 RC packages', () => {
    expect(solid2Baseline).toEqual({
      core: '2.0.0-rc.1',
      universal: '2.0.0-rc.0',
    });
  });

  it('runs Solid fine-grained signals', () => {
    const [count, setCount] = createSignal(0);
    expect(count()).toBe(0);
    setCount(1);
    expect(count()).toBe(1);
  });
});
