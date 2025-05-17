import type { Document } from "./Document";

export class Selection {
  constructor(
    private document: Document,
    public id: number,
  ) {}
  get direction() {
    return this.document.module.Selection_getDirection(
      this.document.tree.ptr,
      this.id,
    );
  }
  getAnchor() {
    return this.document.module.Selection_getAnchor(
      this.document.tree.ptr,
      this.id,
    );
  }
  getFocus() {
    return this.document.module.Selection_getFocus(
      this.document.tree.ptr,
      this.id,
    );
  }
  setAnchor(node: number, offset: number) {
    return this.document.module.Selection_setAnchor(
      this.document.tree.ptr,
      this.id,
      node,
      offset,
    );
  }
  setFocus(node: number, offset: number) {
    return this.document.module.Selection_setFocus(
      this.document.tree.ptr,
      this.id,
      node,
      offset,
    );
  }


}