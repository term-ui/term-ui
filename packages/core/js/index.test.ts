import {
  readFile,
  readdir,
  stat,
} from "node:fs/promises";
import path, { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { raise } from "@term-ui/shared/raise";
import { describe, expect, it } from "vitest";
import { initFromFile } from "./node.js";

const possibleTermInfoPaths = [
  "/etc/terminfo",
  "/lib/terminfo",
  "/usr/share/terminfo",
  "/usr/lib/terminfo",
  "/usr/local/share/terminfo",
  "/usr/local/lib/terminfo",
];
const findFileInPath = async (
  path: string,
  term: string,
) => {
  const firstCharAsHex = term
    .charCodeAt(0)
    .toString(16)
    .padStart(2, "0");

  const fullPath = join(
    path,
    firstCharAsHex,
    term,
  );
  try {
    await stat(fullPath);
    return fullPath;
  } catch (e) {
    return null;
  }
};
const getTermInfoDirPath = async (
  term: string,
) => {
  const termInfoPath = process.env.TERMINFO ?? "";
  if (termInfoPath) {
    const filePath = await findFileInPath(
      termInfoPath,
      term,
    );
    if (filePath) {
      return filePath;
    }
  }
  for (const possibleTermInfoPath of possibleTermInfoPaths) {
    const filePath = await findFileInPath(
      possibleTermInfoPath,
      term,
    );
    if (filePath) {
      return filePath;
    }
  }
  throw new Error("Terminfo directory not found");
};
const getTermInfoBytes =
  async (): Promise<Uint8Array> => {
    const term =
      process.env.TERM ??
      raise("TERM environment variable not set");

    const termInfoPath =
      await getTermInfoDirPath(term);
    const content = await readFile(
      termInfoPath,
      {},
    );

    return new Uint8Array(content.buffer);
  };

const dirpath = dirname(
  fileURLToPath(import.meta.url),
);
console.log(dirpath);
const module = await initFromFile(
  join(dirpath, "../zig-out/bin/core.wasm"),
  {
    writeStream: process.stdout,
    logFn: () => {},
  },
);

describe("TermInfo", () => {
  it("should be able to init from memory", async () => {
    const termInfoBytes =
      await getTermInfoBytes();
    // const termInfo =
    //   module.TermInfo_initFromMemory(
    //     termInfoBytes,
    //   );
    // expect(termInfo).toBeDefined();

    // module.InputManager_init();
  });
});

describe("ArrayList", () => {
  it("should be able to init", () => {
    const list = module.ArrayList_init();
    // expect(list).toBeDefined();
    expect(module.ArrayList_getLength(list)).toBe(
      0,
    );
    {
      const unusedCapacityPointer =
        module.ArrayList_appendUnusedSlice(
          list,
          10,
        );

      expect(
        module.ArrayList_getLength(list),
      ).toBe(10);
      const unusedPointer = new Uint8Array(
        module.memory.buffer,
        unusedCapacityPointer,
        10,
      );

      unusedPointer.set([
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
      ]);
      const view = new Uint8Array(
        module.memory.buffer,
        module.ArrayList_getPointer(list),
        module.ArrayList_getLength(list),
      );
      expect(view).toEqual(
        new Uint8Array([
          1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        ]),
      );
    }
    {
      const unusedCapacityPointer =
        module.ArrayList_appendUnusedSlice(
          list,
          10,
        );
      expect(
        module.ArrayList_getLength(list),
      ).toBe(20);

      expect(
        module.ArrayList_getLength(list),
      ).toBe(20);
      const unusedPointer = new Uint8Array(
        module.memory.buffer,
        unusedCapacityPointer,
        10,
      );

      unusedPointer.set([
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
      ]);

      expect(unusedPointer).toEqual(
        new Uint8Array([
          11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        ]),
      );
    }

    expect(
      new Uint8Array(
        module.memory.buffer,
        module.ArrayList_getPointer(list),
        module.ArrayList_getLength(list),
      ),
    ).toEqual(
      new Uint8Array([
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
        14, 15, 16, 17, 18, 19, 20,
      ]),
    );

    module.ArrayList_clearRetainingCapacity(list);

    expect(module.ArrayList_getLength(list)).toBe(
      0,
    );

    module.ArrayList_deinit(list);
  });
});

describe("InputManager", () => {
  it("should be able to init", () => {
    const tree = module.Tree_init();
    expect(tree).toBeDefined();

    module.Tree_enableInputManager(tree);
    // const inputManager =
    //   module.InputManager_init();
    // expect(inputManager).toBeDefined();
    const arrayList = module.ArrayList_init();

    expect(arrayList).toBeDefined();
    const ptr =
      module.ArrayList_appendUnusedSlice(
        arrayList,
        5,
      );
    const buffer = new Uint8Array(
      module.memory.buffer,
      ptr,
      5,
    );
    buffer.set(Buffer.from("hello"));
    {
      const consumed = module.Tree_consumeEvents(
        tree,
        arrayList,
        undefined,
      );

      expect(consumed).toBe(5);
    }
  });
});

describe("renderer", () => {
  it("should be able to render", () => {
    const tree = module.Tree_init();
    expect(tree).toBeDefined();

    const root = module.Tree_createNode(
      tree,
      `
      background-color: rgba(255,255,255,.1);
      width: 10;
      height: 10;
    `,
    );
    const child = module.Tree_createTextNode(
      tree,
      "Hello, world!",
    );

    module.Tree_appendChild(tree, root, child);
    module.Tree_setStyle(
      tree,
      child,
      "border: rounded; height: 4px;",
    );
    const renderer = module.Renderer_init();
    expect(renderer).toBeDefined();
    // for (let i = 0; i < 100; i++) {
    module.Tree_computeLayout(
      tree,
      "100",
      "max-content",
    );
    module.Renderer_renderToStdout(
      renderer,
      tree,
      false,
    );
    // }

    // module.Renderer_render(renderer, canvas, tree);
  });
});
