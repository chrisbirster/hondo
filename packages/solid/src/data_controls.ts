import {
  type HondoNode,
  type HondoNodeEventHandler,
} from '@hondo/core';
import {
  Column,
  Row,
  Text,
  type HondoStyle,
  type PrimitiveProps,
} from './components.js';
import { keyPayload } from './controls.js';

export interface TreeItem<T> {
  id: string;
  value: T;
  children?: readonly TreeItem<T>[];
  disabled?: boolean;
}

export interface TreeRenderContext {
  depth: number;
  branch: boolean;
  expanded: boolean;
  selected: boolean;
  disabled: boolean;
}

export interface TreeProps<T>
  extends Omit<PrimitiveProps, 'children' | 'focusable' | 'onKey'> {
  items: readonly TreeItem<T>[];
  selectedId?: string;
  expandedIds: readonly string[];
  disabled?: boolean;
  loop?: boolean;
  viewportSize?: number;
  indent?: number;
  itemStyle?: HondoStyle;
  selectedStyle?: HondoStyle;
  disabledStyle?: HondoStyle;
  renderItem?: (item: TreeItem<T>, context: TreeRenderContext) => string;
  onSelectionChange?: (id: string, item: TreeItem<T>) => void;
  onExpandedChange?: (expandedIds: readonly string[]) => void;
  onActivate?: (id: string, item: TreeItem<T>) => void;
  onKey?: HondoNodeEventHandler;
}

interface VisibleTreeRow<T> {
  item: TreeItem<T>;
  depth: number;
  parentId?: string;
  branch: boolean;
  expanded: boolean;
}

export function Tree<T>(props: TreeProps<T>): HondoNode {
  const rowNodes = new Map<string, HondoNode>();

  const visibleRows = () => flattenTree(props.items, new Set(props.expandedIds));

  const rowForId = (id: string) => visibleRows().find(row => row.item.id === id);

  const ensureRowNode = (id: string) => {
    const existing = rowNodes.get(id);
    if (existing) return existing;

    const node = Text({
      get style() {
        const row = rowForId(id);
        if (!row) return props.itemStyle;
        const selected = row.item.id === props.selectedId;
        return {
          ...(props.itemStyle ?? {}),
          ...(selected ? { reverse: true, ...(props.selectedStyle ?? {}) } : {}),
          ...(row.item.disabled ? { dim: true, ...(props.disabledStyle ?? {}) } : {}),
        };
      },
      get children() {
        const row = rowForId(id);
        if (!row) return '';
        const selected = row.item.id === props.selectedId;
        const context: TreeRenderContext = {
          depth: row.depth,
          branch: row.branch,
          expanded: row.expanded,
          selected,
          disabled: row.item.disabled ?? false,
        };
        const label = props.renderItem
          ? props.renderItem(row.item, context)
          : String(row.item.value);
        const indent = Math.max(0, props.indent ?? 2);
        const marker = row.branch ? (row.expanded ? '▾ ' : '▸ ') : '  ';
        return `${' '.repeat(row.depth * indent)}${marker}${label}`;
      },
    });
    rowNodes.set(id, node);
    return node;
  };

  return Column({
    get style() {
      const count = visibleRows().length;
      return {
        clip: true,
        ...(props.viewportSize !== undefined
          ? { height: Math.max(0, Math.min(props.viewportSize, count)) }
          : {}),
        ...(props.style ?? {}),
      };
    },
    get focusable() {
      return !props.disabled && visibleRows().some(row => !row.item.disabled);
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

      const rows = visibleRows();
      if (rows.length === 0) return;
      const key = keyPayload(event);
      if (!key) return;

      const current = currentTreeIndex(rows, props.selectedId);
      if (current < 0) return;
      const row = rows[current];
      if (!row) return;

      if (key.kind === 'up' || key.kind === 'down') {
        const next = nextTreeIndex(
          rows,
          current,
          key.kind === 'down' ? 1 : -1,
          props.loop ?? false,
        );
        if (next !== current) selectTreeRow(props, rows[next]);
        if (props.onSelectionChange) event.preventDefault();
        return;
      }

      if (key.kind === 'right') {
        if (row.branch && !row.expanded && props.onExpandedChange) {
          props.onExpandedChange(addExpandedId(props.expandedIds, row.item.id));
          event.preventDefault();
          return;
        }
        if (row.branch && row.expanded && props.onSelectionChange) {
          const child = firstSelectableDescendant(rows, current, row.depth);
          if (child) props.onSelectionChange(child.item.id, child.item);
          event.preventDefault();
        }
        return;
      }

      if (key.kind === 'left') {
        if (row.branch && row.expanded && props.onExpandedChange) {
          props.onExpandedChange(removeExpandedId(props.expandedIds, row.item.id));
          event.preventDefault();
          return;
        }
        if (row.parentId && props.onSelectionChange) {
          const parent = rows.find(candidate => candidate.item.id === row.parentId);
          if (parent && !parent.item.disabled) {
            props.onSelectionChange(parent.item.id, parent.item);
          }
          event.preventDefault();
        }
        return;
      }

      if (key.kind === 'enter' && props.onActivate && !row.item.disabled) {
        props.onActivate(row.item.id, row.item);
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
      const rows = visibleRows();
      if (rows.length === 0) return [];
      const selected = currentTreeIndex(rows, props.selectedId);
      const viewport = normalizeViewport(props.viewportSize, rows.length);
      const start = viewportStart(Math.max(0, selected), rows.length, viewport);
      return rows
        .slice(start, Math.min(rows.length, start + viewport))
        .map(row => ensureRowNode(row.item.id));
    },
  });
}

export interface TableColumn<T> {
  key: string;
  header: string;
  width: number;
  renderCell: (row: T, rowIndex: number) => string;
  style?: HondoStyle;
  headerStyle?: HondoStyle;
}

export interface TableProps<T>
  extends Omit<PrimitiveProps, 'children' | 'focusable' | 'onKey'> {
  rows: readonly T[];
  columns: readonly TableColumn<T>[];
  selectedIndex: number;
  disabled?: boolean;
  loop?: boolean;
  viewportSize?: number;
  showHeader?: boolean;
  columnGap?: number;
  rowStyle?: HondoStyle;
  selectedStyle?: HondoStyle;
  headerStyle?: HondoStyle;
  onSelectionChange?: (index: number, row: T) => void;
  onActivate?: (index: number, row: T) => void;
  onKey?: HondoNodeEventHandler;
}

export function Table<T>(props: TableProps<T>): HondoNode {
  const rowNodes: HondoNode[] = [];
  let headerNode: HondoNode | undefined;

  const ensureHeader = () => {
    if (headerNode) return headerNode;
    headerNode = Row({
      get style() {
        return { gap: Math.max(0, props.columnGap ?? 1), ...(props.headerStyle ?? {}) };
      },
      get children() {
        return props.columns.map(column =>
          Text({
            style: { width: Math.max(0, column.width), bold: true, ...(column.headerStyle ?? {}) },
            children: column.header,
          }),
        );
      },
    });
    return headerNode;
  };

  const ensureRows = () => {
    while (rowNodes.length < props.rows.length) {
      const index = rowNodes.length;
      rowNodes.push(
        Row({
          get style() {
            const selected = index === clampIndex(props.selectedIndex, props.rows.length);
            return {
              gap: Math.max(0, props.columnGap ?? 1),
              ...(props.rowStyle ?? {}),
              ...(selected ? { reverse: true, ...(props.selectedStyle ?? {}) } : {}),
            };
          },
          get children() {
            const row = props.rows[index];
            if (row === undefined) return [];
            return props.columns.map(column =>
              Text({
                style: { width: Math.max(0, column.width), ...(column.style ?? {}) },
                children: column.renderCell(row, index),
              }),
            );
          },
        }),
      );
    }
  };

  return Column({
    get style() {
      const viewport = normalizeViewport(props.viewportSize, props.rows.length);
      const headerRows = props.showHeader === false ? 0 : 1;
      return {
        clip: true,
        ...(props.viewportSize !== undefined ? { height: viewport + headerRows } : {}),
        ...(props.style ?? {}),
      };
    },
    get focusable() {
      return !props.disabled && props.rows.length > 0;
    },
    get autoFocus() {
      return props.autoFocus;
    },
    get ref() {
      return props.ref;
    },
    onKey: event => {
      props.onKey?.(event);
      if (event.defaultPrevented || props.disabled || props.rows.length === 0) return;
      const key = keyPayload(event);
      if (!key) return;

      if (key.kind === 'up' || key.kind === 'down') {
        const current = clampIndex(props.selectedIndex, props.rows.length);
        const next = nextIndex(
          current,
          key.kind === 'down' ? 1 : -1,
          props.rows.length,
          props.loop ?? false,
        );
        if (next !== current) {
          const row = props.rows[next];
          if (row !== undefined) props.onSelectionChange?.(next, row);
        }
        if (props.onSelectionChange) event.preventDefault();
        return;
      }

      if (key.kind === 'enter' && props.onActivate) {
        const index = clampIndex(props.selectedIndex, props.rows.length);
        const row = props.rows[index];
        if (row !== undefined) {
          props.onActivate(index, row);
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
      const count = props.rows.length;
      const viewport = normalizeViewport(props.viewportSize, count);
      const selected = clampIndex(props.selectedIndex, count);
      const start = viewportStart(selected, count, viewport);
      const visible = rowNodes.slice(start, Math.min(count, start + viewport));
      return props.showHeader === false ? visible : [ensureHeader(), ...visible];
    },
  });
}

function flattenTree<T>(
  items: readonly TreeItem<T>[],
  expandedIds: ReadonlySet<string>,
  depth = 0,
  parentId?: string,
): VisibleTreeRow<T>[] {
  const rows: VisibleTreeRow<T>[] = [];
  for (const item of items) {
    const branch = (item.children?.length ?? 0) > 0;
    const expanded = branch && expandedIds.has(item.id);
    rows.push({ item, depth, parentId, branch, expanded });
    if (expanded && item.children) {
      rows.push(...flattenTree(item.children, expandedIds, depth + 1, item.id));
    }
  }
  return rows;
}

function currentTreeIndex<T>(rows: readonly VisibleTreeRow<T>[], selectedId?: string): number {
  if (selectedId !== undefined) {
    const index = rows.findIndex(row => row.item.id === selectedId);
    if (index >= 0) return index;
  }
  return rows.findIndex(row => !row.item.disabled);
}

function nextTreeIndex<T>(
  rows: readonly VisibleTreeRow<T>[],
  current: number,
  direction: 1 | -1,
  loop: boolean,
): number {
  if (rows.length === 0) return -1;
  let index = current;
  for (let attempts = 0; attempts < rows.length; attempts += 1) {
    const candidate = nextIndex(index, direction, rows.length, loop);
    if (candidate === index) return current;
    index = candidate;
    if (!rows[index]?.item.disabled) return index;
  }
  return current;
}

function firstSelectableDescendant<T>(
  rows: readonly VisibleTreeRow<T>[],
  current: number,
  depth: number,
): VisibleTreeRow<T> | undefined {
  for (let index = current + 1; index < rows.length; index += 1) {
    const row = rows[index];
    if (!row || row.depth <= depth) break;
    if (!row.item.disabled) return row;
  }
  return undefined;
}

function selectTreeRow<T>(props: TreeProps<T>, row?: VisibleTreeRow<T>): void {
  if (!row || row.item.disabled || row.item.id === props.selectedId) return;
  props.onSelectionChange?.(row.item.id, row.item);
}

function addExpandedId(ids: readonly string[], id: string): readonly string[] {
  return ids.includes(id) ? ids : [...ids, id];
}

function removeExpandedId(ids: readonly string[], id: string): readonly string[] {
  return ids.filter(candidate => candidate !== id);
}

function normalizeViewport(viewportSize: number | undefined, count: number): number {
  if (count <= 0) return 0;
  if (viewportSize === undefined) return count;
  return clamp(Math.trunc(viewportSize), 0, count);
}

function viewportStart(selected: number, count: number, viewport: number): number {
  if (viewport <= 0 || count <= viewport) return 0;
  return clamp(selected - viewport + 1, 0, count - viewport);
}

function clampIndex(index: number, count: number): number {
  if (count <= 0) return 0;
  return clamp(Math.trunc(index), 0, count - 1);
}

function nextIndex(
  current: number,
  direction: 1 | -1,
  count: number,
  loop: boolean,
): number {
  if (count <= 0) return 0;
  const next = current + direction;
  if (loop) return (next + count) % count;
  return clamp(next, 0, count - 1);
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}
