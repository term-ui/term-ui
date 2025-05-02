import type { Document } from "./Document";
import { Node } from "./Node";
import type { DomEvent } from "./types";

export class TextElement extends Node {
  constructor(
    private document: Document,
    id: number,
  ) {
    if (document.getElement(id)) {
      throw new Error("Node already exists");
    }
    super(document.tree, id);
    document.addElement(this);
  }
  static fromNode(
    document: Document,
    node: number,
  ) {
    {
      const element = document.getElement(node);
      if (element) {
        return element as TextElement;
      }
    }
    const element = new TextElement(
      document,
      node,
    );
    element.document = document;
    return element;
  }
  setText(text: string) {
    this.tree.module.Tree_setText(
      this.tree.ptr,
      this.id,
      text,
    );
  }
  emitEvent = (_: DomEvent) => {
    // debug.log(event);
  };
  [Symbol.for("nodejs.util.inspect.custom")]() {
    return `<text (${this.id})/>`;
  }
  dispose() {
    super.dispose();
    this.document.removeElement(this);
  }
  disposeRecursively() {
    this.dispose();
  }
  [Symbol.dispose] = () => {
    this.dispose();
  };
}
