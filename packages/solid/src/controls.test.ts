import { createSignal, flush } from 'solid-js';
import { describe, expect, it } from 'vitest';
import { HondoHost, RecordingMutationBridge, installHost, type HondoNode } from '@hondo/core';
import { Input, List, ScrollView } from './controls.js';
import { Text } from './components.js';
import { render } from './renderer.js';

function textContent(node: HondoNode): string {
  if (node.isText) return node.textValue ?? '';
  return node.children.map(textContent).join('');
}

function mountHost(code: () => HondoNode) {
  const bridge = new RecordingMutationBridge();
  const host = new HondoHost(bridge);
  const restore = installHost(host);
  const dispose = render(code, host.root);
  flush();
  bridge.take();
  return { bridge, host, dispose, restore };
}

describe('Input', () => {
  it('edits controlled Unicode text through native key payloads and submits', () => {
    const [value, setValue] = createSignal('A😀');
    const submitted: string[] = [];
    let input!: HondoNode;

    const mounted = mountHost(() => {
      input = Input({
        get value() {
          return value();
        },
        placeholder: 'Type here',
        onInput: setValue,
        onSubmit: next => submitted.push(next),
      });
      return input;
    });

    mounted.host.dispatchNodeEvent(input.id, 'key', { kind: 'backspace' });
    flush();
    expect(value()).toBe('A');
    expect(textContent(input)).toBe('A');

    mounted.host.dispatchNodeEvent(input.id, 'key', {
      kind: 'codepoint',
      codepoint: 'λ'.codePointAt(0)!,
    });
    flush();
    expect(value()).toBe('Aλ');
    expect(textContent(input)).toBe('Aλ');

    mounted.host.dispatchNodeEvent(input.id, 'key', { kind: 'enter' });
    expect(submitted).toEqual(['Aλ']);

    mounted.dispose();
    mounted.restore();
  });

  it('shows a placeholder and allows user key handlers to prevent editing', () => {
    const [value, setValue] = createSignal('');
    let input!: HondoNode;

    const mounted = mountHost(() => {
      input = Input({
        get value() {
          return value();
        },
        placeholder: 'Search',
        onInput: setValue,
        onKey: event => event.preventDefault(),
      });
      return input;
    });

    expect(textContent(input)).toBe('Search');
    mounted.host.dispatchNodeEvent(input.id, 'key', {
      kind: 'codepoint',
      codepoint: 'x'.codePointAt(0)!,
    });
    flush();
    expect(value()).toBe('');
    expect(textContent(input)).toBe('Search');

    mounted.dispose();
    mounted.restore();
  });
});

describe('List', () => {
  it('moves controlled selection, scrolls the visible window, and activates', () => {
    const items = ['alpha', 'beta', 'gamma'];
    const [selected, setSelected] = createSignal(0);
    const activated: string[] = [];
    let list!: HondoNode;

    const mounted = mountHost(() => {
      list = List({
        items,
        get selectedIndex() {
          return selected();
        },
        viewportSize: 2,
        onSelectionChange: index => setSelected(index),
        onActivate: (_index, item) => activated.push(item),
      });
      return list;
    });

    expect(list.children.map(textContent)).toEqual(['alpha', 'beta']);

    mounted.host.dispatchNodeEvent(list.id, 'key', { kind: 'down' });
    flush();
    expect(selected()).toBe(1);
    expect(list.children.map(textContent)).toEqual(['alpha', 'beta']);

    mounted.host.dispatchNodeEvent(list.id, 'key', { kind: 'down' });
    flush();
    expect(selected()).toBe(2);
    expect(list.children.map(textContent)).toEqual(['beta', 'gamma']);

    mounted.host.dispatchNodeEvent(list.id, 'key', { kind: 'enter' });
    expect(activated).toEqual(['gamma']);

    mounted.host.dispatchNodeEvent(list.id, 'key', { kind: 'down' });
    flush();
    expect(selected()).toBe(2);

    mounted.dispose();
    mounted.restore();
  });
});

describe('ScrollView', () => {
  it('moves a controlled vertical window with arrow keys', () => {
    const [offset, setOffset] = createSignal(0);
    let view!: HondoNode;

    const mounted = mountHost(() => {
      const rows = [
        Text({ children: 'one' }),
        Text({ children: 'two' }),
        Text({ children: 'three' }),
      ];
      view = ScrollView({
        children: rows,
        get offset() {
          return offset();
        },
        viewportSize: 2,
        onOffsetChange: setOffset,
      });
      return view;
    });

    expect(view.children.map(textContent)).toEqual(['one', 'two']);

    mounted.host.dispatchNodeEvent(view.id, 'key', { kind: 'down' });
    flush();
    expect(offset()).toBe(1);
    expect(view.children.map(textContent)).toEqual(['two', 'three']);

    mounted.host.dispatchNodeEvent(view.id, 'key', { kind: 'down' });
    flush();
    expect(offset()).toBe(1);

    mounted.host.dispatchNodeEvent(view.id, 'key', { kind: 'up' });
    flush();
    expect(offset()).toBe(0);
    expect(view.children.map(textContent)).toEqual(['one', 'two']);

    mounted.dispose();
    mounted.restore();
  });
});
