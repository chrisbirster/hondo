import {
  HondoHost,
  NativeMutationBridge,
  installHost,
  type HondoMutationBridge,
} from '@hondo/core';
import {
  createElement,
  createSignal,
  insert,
  render,
} from '@hondo/solid';
import { flush } from 'solid-js';

export interface MountedCounter {
  increment(): void;
  dispose(): void;
}

export function mountCounter(
  bridge: HondoMutationBridge = new NativeMutationBridge(),
): MountedCounter {
  const host = new HondoHost(bridge);
  const restoreHost = installHost(host);
  const [count, setCount] = createSignal(0);

  const disposeRender = render(() => {
    const text = createElement('text');
    insert(text, () => `Count: ${count()}`);
    return text;
  }, host.root);
  flush();

  let disposed = false;

  return {
    increment() {
      if (disposed) throw new Error('Counter has been disposed');
      setCount(value => value + 1);
      flush();
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      disposeRender();
      restoreHost();
    },
  };
}
