import {
  type HondoNode,
  type HondoNodeEvent,
  type HondoNodeEventHandler,
} from '@hondo/core';
import {
  Column,
  Text,
  type HondoRef,
  type HondoStyle,
  type PrimitiveProps,
} from './components.js';

export type HondoKeyKind =
  | 'codepoint'
  | 'enter'
  | 'backspace'
  | 'escape'
  | 'ctrlC'
  | 'up'
  | 'down'
  | 'left'
  | 'right';

export interface HondoKeyPayload {
  kind: HondoKeyKind;
  codepoint?: number;
}

export interface InputProps
  extends Omit<PrimitiveProps, 'children' | 'focusable' | 'onKey'> {
  value: string;
  placeholder?: string;
  disabled?: boolean;
  onInput?: (value: string) => void;
  onSubmit?: (value: string) => void;
  onKey?: HondoNodeEventHandler;
}

export function Input(props: InputProps): HondoNode {
  return Text({
    get style() {
      const style = props.style;
      if (props.value.length > 0 || !props.placeholder) return style;
      return { dim: true, ...(style ?? {}) };
    },
    get focusable() {
      return !props.disabled;
    },
    get autoFocus() {
      return props.autoFocus;
    },
    get ref() {
      return props.ref;
    },
    onKey: event => {
      props.onKey?.(event);
      if (event.defaultPrevented || props.disabled) return;

      const key = keyPayload(event);
      if (!key) return;

      if (key.kind === 'codepoint' && key.codepoint !== undefined) {
        props.onInput?.(`${props.value}${String.fromCodePoint(key.codepoint)}`);
        if (props.onInput) event.preventDefault();
        return;
      }

      if (key.kind === 'backspace') {
        props.onInput?.(removeLastCodePoint(props.value));
        if (props.onInput) event.preventDefault();
        return;
      }

      if (key.kind === 'enter' && props.onSubmit) {
        props.onSubmit(props.value);
        event.preventDefault();
      }
    },
    onKeyCapture: props.onKeyCapture,
    onMouse: props.onMouse,
    onMouseCapture: props.onMouseCapture,
    onFocusIn: props.onFocusIn,
    onFocusInCapture: props.onFocusInCapture,
    onFocusOut: props.onFocusOut,
    onFocusOutCapture: props.onFocusOutCapture,
    get children() {
      return props.value.length > 0 ? props.value : (props.placeholder ?? '');
    },
  });
}

export interface ListProps<T>
  extends Omit<PrimitiveProps, 'children' | 'focusable' | 'onKey'> {
  items: readonly T[];
  selectedIndex: number;
  disabled?: boolean;
  loop?: boolean;
  viewportSize?: number;
  itemStyle?: HondoStyle;
  selectedStyle?: HondoStyle;
  renderItem?: (item: T, index: number, selected: boolean) => string;
  onSelectionChange?: (index: number, item: T) => void;
  onActivate?: (index: number, item: T) => void;
  onKey?: HondoNodeEventHandler;
}

export function List<T>(props: ListProps<T>): HondoNode {
  const rows: HondoNode[] = [];

  const ensureRows = () => {
    while (rows.length < props.items.length) {
      const index = rows.length;
      rows.push(
        Text({
          get style() {
            const selected = index === clampIndex(props.selectedIndex, props.items.length);
            return selected
              ? { ...(props.itemStyle ?? {}), reverse: true, ...(props.selectedStyle ?? {}) }
              : props.itemStyle;
          },
          get children() {
            const item = props.items[index];
            if (item === undefined) return '';
            const selected = index === clampIndex(props.selectedIndex, props.items.length);
            return props.renderItem
              ? props.renderItem(item, index, selected)
              : String(item);
          },
        }),
      );
    }
  };

  return Column({
    get style() {
      return {
        clip: true,
        ...(props.viewportSize !== undefined ? { height: Math.max(0, props.viewportSize) } : {}),
        ...(props.style ?? {}),
      };
    },
    get focusable() {
      return !props.disabled;
    },
    get autoFocus() {
      return props.autoFocus;
    },
    get ref() {
      return props.ref;
    },
    onKey: event => {
      props.onKey?.(event);
      if (event.defaultPrevented || props.disabled || props.items.length === 0) return;

      const key = keyPayload(event);
      if (!key) return;

      if (key.kind === 'up' || key.kind === 'down') {
        const direction = key.kind === 'down' ? 1 : -1;
        const next = nextIndex(
          clampIndex(props.selectedIndex, props.items.length),
          direction,
          props.items.length,
          props.loop ?? false,
        );
        if (next !== props.selectedIndex) {
          const item = props.items[next];
          if (item !== undefined) props.onSelectionChange?.(next, item);
        }
        if (props.onSelectionChange) event.preventDefault();
        return;
      }

      if (key.kind === 'enter' && props.onActivate) {
        const index = clampIndex(props.selectedIndex, props.items.length);
        const item = props.items[index];
        if (item !== undefined) {
          props.onActivate(index, item);
          event.preventDefault();
        }
      }
    },
    onKeyCapture: props.onKeyCapture,
    onMouse: props.onMouse,
    onMouseCapture: props.onMouseCapture,
    onFocusIn: props.onFocusIn,
    onFocusInCapture: props.onFocusInCapture,
    onFocusOut: props.onFocusOut,
    onFocusOutCapture: props.onFocusOutCapture,
    get children() {
      ensureRows();
      const count = props.items.length;
      if (count === 0) return [];
      const viewport = normalizeViewport(props.viewportSize, count);
      const selected = clampIndex(props.selectedIndex, count);
      const start = viewportStart(selected, count, viewport);
      return rows.slice(start, Math.min(count, start + viewport));
    },
  });
}

export interface ScrollViewProps
  extends Omit<PrimitiveProps, 'children' | 'focusable' | 'onKey'> {
  children: readonly unknown[];
  offset?: number;
  viewportSize?: number;
  disabled?: boolean;
  onOffsetChange?: (offset: number) => void;
  onKey?: HondoNodeEventHandler;
}

export function ScrollView(props: ScrollViewProps): HondoNode {
  return Column({
    get style() {
      return {
        clip: true,
        ...(props.viewportSize !== undefined ? { height: Math.max(0, props.viewportSize) } : {}),
        ...(props.style ?? {}),
      };
    },
    get focusable() {
      return !props.disabled && props.onOffsetChange !== undefined;
    },
    get autoFocus() {
      return props.autoFocus;
    },
    get ref() {
      return props.ref;
    },
    onKey: event => {
      props.onKey?.(event);
      if (event.defaultPrevented || props.disabled || !props.onOffsetChange) return;

      const key = keyPayload(event);
      if (!key || (key.kind !== 'up' && key.kind !== 'down')) return;

      const viewport = normalizeViewport(props.viewportSize, props.children.length);
      const maximum = Math.max(0, props.children.length - viewport);
      const current = clamp(props.offset ?? 0, 0, maximum);
      const next = clamp(current + (key.kind === 'down' ? 1 : -1), 0, maximum);
      if (next !== current) props.onOffsetChange(next);
      event.preventDefault();
    },
    onKeyCapture: props.onKeyCapture,
    onMouse: props.onMouse,
    onMouseCapture: props.onMouseCapture,
    onFocusIn: props.onFocusIn,
    onFocusInCapture: props.onFocusInCapture,
    onFocusOut: props.onFocusOut,
    onFocusOutCapture: props.onFocusOutCapture,
    get children() {
      const viewport = normalizeViewport(props.viewportSize, props.children.length);
      const maximum = Math.max(0, props.children.length - viewport);
      const start = clamp(props.offset ?? 0, 0, maximum);
      return props.children.slice(start, start + viewport);
    },
  });
}

export function keyPayload(event: HondoNodeEvent): HondoKeyPayload | undefined {
  if (event.type !== 'key') return undefined;
  const payload = event.payload;
  if (payload === null || Array.isArray(payload) || typeof payload !== 'object') return undefined;

  const kind = payload.kind;
  if (typeof kind !== 'string' || !isKeyKind(kind)) return undefined;

  if (kind === 'codepoint') {
    return typeof payload.codepoint === 'number'
      ? { kind, codepoint: payload.codepoint }
      : undefined;
  }
  return { kind };
}

function removeLastCodePoint(value: string): string {
  const codepoints = Array.from(value);
  codepoints.pop();
  return codepoints.join('');
}

function isKeyKind(value: string): value is HondoKeyKind {
  return value === 'codepoint'
    || value === 'enter'
    || value === 'backspace'
    || value === 'escape'
    || value === 'ctrlC'
    || value === 'up'
    || value === 'down'
    || value === 'left'
    || value === 'right';
}

function nextIndex(current: number, direction: -1 | 1, count: number, loop: boolean): number {
  if (count <= 0) return 0;
  const next = current + direction;
  if (loop) return (next + count) % count;
  return clamp(next, 0, count - 1);
}

function clampIndex(index: number, count: number): number {
  if (count <= 0) return 0;
  return clamp(Math.trunc(index), 0, count - 1);
}

function normalizeViewport(viewportSize: number | undefined, count: number): number {
  if (viewportSize === undefined) return count;
  return clamp(Math.trunc(viewportSize), 0, count);
}

function viewportStart(selected: number, count: number, viewport: number): number {
  if (viewport <= 0 || count <= viewport) return 0;
  return clamp(selected - viewport + 1, 0, count - viewport);
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

export type { HondoRef, HondoStyle };
