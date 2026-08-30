import {
  HondoHost,
  NativeMutationBridge,
  installHost,
  type HondoMutationBridge,
  type HondoNodeEvent,
  type HondoValue,
} from '@hondo/core';
import {
  createElement,
  createSignal,
  insert,
  render,
  setProp,
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

  const increment = () => {
    setCount(value => value + 1);
    flush();
  };

  const disposeRender = render(() => {
    const text = createElement('text');
    setProp(text, 'focusable', true);
    setProp(text, 'onKey', (event: HondoNodeEvent) => {
      if (!isActivationKey(event.payload)) return;
      event.preventDefault();
      increment();
    });
    insert(text, () => `Count: ${count()}`);
    return text;
  }, host.root);
  flush();

  let disposed = false;

  return {
    increment() {
      if (disposed) throw new Error('Counter has been disposed');
      increment();
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      disposeRender();
      restoreHost();
    },
  };
}

function isActivationKey(payload: HondoValue): boolean {
  if (!payload || Array.isArray(payload) || typeof payload !== 'object') return false;
  if (payload.kind === 'enter') return true;
  return payload.kind === 'codepoint' && payload.codepoint === 32;
}
