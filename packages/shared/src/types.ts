export type ReadStream = Pick<
  NodeJS.ReadStream,
  "read" | "on" | "off" | "setRawMode"
>;
export type WriteStream = Pick<
  NodeJS.WriteStream,
  "write" | "columns" | "rows" | "on" | "off"
>;
