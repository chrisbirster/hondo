import {
  encodeHondoValue,
  type HondoMutationBridge,
} from './bridge.js';

export interface HondoNode {
  readonly id: number;
  readonly type: string;
  readonly isText: boolean;
  parent: HondoNode | null;
  children: HondoNode[];
  textValue: string | null;
}

export class HondoHost {
  readonly root: HondoNode = {
    id: 0,
    type: 'root',
    isText: false,
    parent: null,
    children: [],
    textValue: null,
  };

  private nextNodeId = 1;

  constructor(readonly bridge: HondoMutationBridge) {}

  createElement(type: string): HondoNode {
    const node = this.createHostNode(type, false, null);
    this.bridge.createElement(node.id, type);
    return node;
  }

  createTextNode(value: string): HondoNode {
    const node = this.createHostNode('#text', true, value);
    this.bridge.createTextNode(node.id, value);
    return node;
  }

  replaceText(node: HondoNode, value: string): void {
    if (!node.isText) throw new TypeError('replaceText requires a Hondo text node');
    if (node.textValue === value) return;

    node.textValue = value;
    this.bridge.replaceText(node.id, value);
  }

  setProperty(node: HondoNode, name: string, value: unknown): void {
    this.bridge.setProperty(node.id, name, encodeHondoValue(value));
  }

  insertNode(parent: HondoNode, node: HondoNode, anchor?: HondoNode | null): void {
    if (node === parent) throw new Error('A Hondo node cannot contain itself');
    if (anchor === node) throw new Error('A Hondo node cannot be its own insertion anchor');
    if (anchor && anchor.parent !== parent) {
      throw new Error('Hondo insertion anchor must be a child of the target parent');
    }

    if (node.parent) {
      const previousIndex = node.parent.children.indexOf(node);
      if (previousIndex >= 0) node.parent.children.splice(previousIndex, 1);
    }

    const anchorIndex = anchor ? parent.children.indexOf(anchor) : -1;
    const insertionIndex = anchorIndex >= 0 ? anchorIndex : parent.children.length;
    parent.children.splice(insertionIndex, 0, node);
    node.parent = parent;

    this.bridge.insertNode(parent.id, node.id, anchor?.id ?? null);
  }

  removeNode(parent: HondoNode, node: HondoNode): void {
    const index = parent.children.indexOf(node);
    if (index < 0 || node.parent !== parent) {
      throw new Error('Cannot remove a node that is not a child of the supplied parent');
    }

    parent.children.splice(index, 1);
    node.parent = null;
    this.bridge.removeNode(parent.id, node.id);
  }

  isTextNode(node: HondoNode): boolean {
    return node.isText;
  }

  getParentNode(node: HondoNode): HondoNode | undefined {
    return node.parent ?? undefined;
  }

  getFirstChild(node: HondoNode): HondoNode | undefined {
    return node.children[0];
  }

  getNextSibling(node: HondoNode): HondoNode | undefined {
    const parent = node.parent;
    if (!parent) return undefined;

    const index = parent.children.indexOf(node);
    return index >= 0 ? parent.children[index + 1] : undefined;
  }

  private createHostNode(type: string, isText: boolean, textValue: string | null): HondoNode {
    return {
      id: this.nextNodeId++,
      type,
      isText,
      parent: null,
      children: [],
      textValue,
    };
  }
}

let activeHost: HondoHost | undefined;

export function installHost(host: HondoHost): () => void {
  const previous = activeHost;
  activeHost = host;
  let restored = false;

  return () => {
    if (restored) return;
    restored = true;
    if (activeHost === host) activeHost = previous;
  };
}

export function getHost(): HondoHost {
  if (!activeHost) throw new Error('No Hondo host is installed');
  return activeHost;
}
