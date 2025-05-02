import { initFromFile } from "@term-ui/core/node";
import { describe, it } from "vitest";
import { InputManager } from "./InputManager";
import { Tree } from "./Tree";
const module = await initFromFile(undefined);
describe("InputManager", () => {
  it("should be able to consume events", () => {
    const tree = Tree.init(module);

    const inputManager = new InputManager(
      module,
      process.stdin,
      tree,
    );
    inputManager.buffer.appendSlice(
      new TextEncoder().encode("hello"),
    );
    inputManager.consumeEvents();
    // inputManager.buffer.appendString("world");
    // const consumed = inputManager.consumeEvents();
  });
});
