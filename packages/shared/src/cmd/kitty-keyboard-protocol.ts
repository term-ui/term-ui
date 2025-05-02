import type {
  ReadStream,
  WriteStream,
} from "../types";
import { csi, decode, query } from "./utils";

export const kittyKeyboardProtocol = {
  DISAMBIGUATE: 0b1,
  REPORT_EVENTS: 0b10,
  REPORT_ALTERNATES: 0b100,
  REPORT_ALL_KEYS: 0b1000,
  REPORT_TEXT: 0b10000,
  ALL: 0b11111,
  QUERY_SEQUENCE: csi("?u"),

  push: (mode: number) => csi(`>${mode}u`),
  pop: (mode: number) => csi(`<${mode}u`),
  query: ({
    signal = AbortSignal.timeout(100),
    ...rest
  }: {
    signal?: AbortSignal;
    readStream?: ReadStream;
    writeStream?: WriteStream;
  } = {}) =>
    query(kittyKeyboardProtocol.QUERY_SEQUENCE, {
      transform: (data) => {
        const decoded = decode(data);
        const [, mode] =
          decoded.match(/^\x1b\[\?(\d+)u/) ?? [];
        return typeof mode === "string"
          ? Number.parseInt(mode)
          : undefined;
      },
      checker: Number.isFinite,
      signal,
      ...rest,
    }),
};
