import type { Tree } from "./Tree";

export class Node {
  tree: Tree;
  id: number;
  constructor(tree: Tree, id: number) {
    this.tree = tree;
    this.id = id;
  }
  getKind() {
    return this.tree.module.Tree_getNodeKind(
      this.tree.ptr,
      this.id,
    );
  }
  setStyle(style: string) {
    this.tree.module.Tree_setStyle(
      this.tree.ptr,
      this.id,
      style,
    );
  }
  dispose() {
    this.tree.module.Tree_destroyNode(
      this.tree.ptr,
      this.id,
    );
  }
  [Symbol.dispose]() {
    this.dispose();
  }
}
