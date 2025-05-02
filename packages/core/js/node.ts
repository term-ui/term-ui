import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { memoize } from "lodash-es";
import { type InitArgs, init } from "./index.js";

export type { Module } from "./index.js";

export const distDir = join(
  dirname(fileURLToPath(import.meta.url)),
);

const _initFromFile = async (
  path: string = join(distDir, "core.wasm"),
  args: InitArgs = {},
) => {
  const bytes = await readFile(path);
  return await init(new Uint8Array(bytes), args);
};

export const initFromFile: typeof _initFromFile =
  memoize(_initFromFile);
