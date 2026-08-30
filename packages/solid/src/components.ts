import { type HondoNode, type HondoNodeEventHandler } from '@hondo/core';
import { effect, insert, createElement, setProp } from './renderer.js';

export type HondoColor =
  | 'default'
  | 'black'
  | 'red'
  | 'green'
  | 'yellow'
  | 'blue'
  | 'magenta'
  | 'cyan'
  | 'white'
  | 'bright-black'
  | 'bright-red'
  | 'bright-green'
  | 'bright-yellow'
  | 'bright-blue'
  | 'bright-magenta'
  | 'bright-cyan'
  | 'bright-white'
  | `#${string}`
  | number;

export type HondoAlign = 'start' | 'center' | 'end' | 'stretch';
export type HondoJustify = 'start' | 'center' | 'end' | 'space-between';
export type HondoDirection = 'row' | 'column';

export interface HondoStyle {
  direction?: HondoDirection;
  width?: number;
  height?: number;
  minWidth?: number;
  minHeight?: number;
  maxWidth?: number;
  maxHeight?: number;
  basis?: number;
  grow?: number;
  shrink?: number;
  gap?: number;
  padding?: number;
  paddingX?: number;
  paddingY?: number;
  paddingTop?: number;
  paddingRight?: number;
  paddingBottom?: number;
  paddingLeft?: number;
  align?: HondoAlign;
  justify?: HondoJustify;
  clip?: boolean;
  foreground?: HondoColor;
  background?: HondoColor;
  bold?: boolean;
  dim?: boolean;
  italic?: boolean;
  underline?: boolean;
  reverse?: boolean;
  inverse?: boolean;
  strikethrough?: boolean;
}

export interface HondoRefHandle {
  readonly node: HondoNode;
  focus(): void;
}

export type HondoRef = (handle: HondoRefHandle) => void;

export interface HondoEventProps {
  onKey?: HondoNodeEventHandler;
  onKeyCapture?: HondoNodeEventHandler;
  onMouse?: HondoNodeEventHandler;
  onMouseCapture?: HondoNodeEventHandler;
  onFocusIn?: HondoNodeEventHandler;
  onFocusInCapture?: HondoNodeEventHandler;
  onFocusOut?: HondoNodeEventHandler;
  onFocusOutCapture?: HondoNodeEventHandler;
}

export interface PrimitiveProps extends HondoEventProps {
  children?: unknown;
  style?: HondoStyle;
  focusable?: boolean;
  autoFocus?: boolean;
  ref?: HondoRef;
}

export interface SpacerProps extends HondoEventProps {
  size?: number;
  grow?: number;
  shrink?: number;
  style?: HondoStyle;
}

const eventProperties = [
  'onKey',
  'onKeyCapture',
  'onMouse',
  'onMouseCapture',
  'onFocusIn',
  'onFocusInCapture',
  'onFocusOut',
  'onFocusOutCapture',
] as const;

export function Text(props: PrimitiveProps = {}): HondoNode {
  return primitive('text', props);
}

export function Box(props: PrimitiveProps = {}): HondoNode {
  return primitive('box', props);
}

export function Stack(props: PrimitiveProps = {}): HondoNode {
  return primitive('column', props);
}

export function Row(props: PrimitiveProps = {}): HondoNode {
  return primitive('row', props);
}

export function Column(props: PrimitiveProps = {}): HondoNode {
  return primitive('column', props);
}

export function Spacer(props: SpacerProps = {}): HondoNode {
  const node = createElement('spacer');
  effect(() => {
    setProp(node, 'style', {
      basis: props.size ?? 0,
      grow: props.grow ?? 1,
      shrink: props.shrink ?? 1,
      ...(props.style ?? {}),
    });
  });
  applyEvents(node, props);
  return node;
}

let focusRequestSequence = 0;

export function focusNode(node: HondoNode): void {
  setProp(node, 'focusRequest', ++focusRequestSequence);
}

function primitive(type: string, props: PrimitiveProps): HondoNode {
  const node = createElement(type);

  effect(() => {
    if (props.style !== undefined) setProp(node, 'style', props.style);
    if (props.focusable !== undefined || props.autoFocus) {
      setProp(node, 'focusable', props.focusable ?? true);
    }
  });

  applyEvents(node, props);
  if (props.autoFocus) focusNode(node);

  if (props.ref) {
    const handle: HondoRefHandle = {
      node,
      focus() {
        focusNode(node);
      },
    };
    props.ref(handle);
  }

  insert(node, () => props.children);
  return node;
}

function applyEvents(node: HondoNode, props: HondoEventProps): void {
  for (const name of eventProperties) {
    const handler = props[name];
    if (handler !== undefined) setProp(node, name, handler);
  }
}
