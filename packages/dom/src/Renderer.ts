import type { Module } from "@term-ui/core";
import type { WriteStream } from "@term-ui/shared/types";
import type { Tree } from "./Tree";

export class Renderer {
  ptr: number;

  constructor(
    public module: Module,
    public stdout: WriteStream,
  ) {
    this.ptr = module.Renderer_init();
  }
  static init(
    module: Module,
    stdout: WriteStream,
  ) {
    return new Renderer(module, stdout);
  }

  getNodeAt(x: number, y: number) {
    return this.module.Renderer_getNodeAt(
      this.ptr,
      x,
      y,
    );
  }
  renderToStdout(
    tree: Tree,
    clearScreen = false,
  ) {
    this.module.Renderer_renderToStdout(
      this.ptr,
      tree.ptr,
      clearScreen,
    );
  }
  dispose() {
    this.module.Renderer_deinit(this.ptr);
  }
  [Symbol.dispose]() {
    this.dispose();
  }
}
