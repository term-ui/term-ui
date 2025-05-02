import fs from "node:fs/promises";
import { inspect } from "node:util";
const LOG_PATH = "./app.log";

try {
  if (!(await fs.exists(LOG_PATH))) {
    await fs.writeFile(LOG_PATH, "");
  }
} catch {}

const formatDate = (date: Date) => {
  return date.toLocaleString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
};
let lastMessagePromise: Promise<unknown> =
  Promise.resolve();
const file = await fs.open(LOG_PATH, "a");

export const log = (...args: unknown[]) => {
  const logs: string[] = [];
  for (const arg of args) {
    logs.push(
      inspect(arg, {
        depth: null,
        colors: true,
      }),
    );
  }
  const date = new Date();
  const formatted = formatDate(date);
  const stack =
    new Error().stack?.split("\n")[2] ?? "";
  const filePath =
    stack.match(/\(([^)]+)\)/)?.[1] ?? "";

  const path = filePath
    .split("/")
    .slice(-2)
    .join("/");

  const message = `[${path} ${formatted}] ${logs.join(" ")}`;
  // const messageWithStack = `${message}\n${stack}`;

  // const message = `[${formatted}] ${logs.join(" ")}`;
  // to make sure that the log is written in order
  lastMessagePromise = lastMessagePromise.finally(
    () => {
      file.write;
      return file.write(`${message}\n`);
    },
  );
};

export const err = (error: unknown) => {
  const normalizedError =
    error instanceof Error
      ? error
      : new Error(String(error));
  log(
    `\x1b[31m${normalizedError.message}\x1b[0m`,
    normalizedError.stack,
  );
};
export const trace = (...args: unknown[]) => {
  const stack = new Error().stack;
  log(...args, stack);
};
