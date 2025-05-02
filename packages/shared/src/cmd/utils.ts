import type {
  ReadStream,
  WriteStream,
} from "../types";

const decoder = new TextDecoder();

export const decode =
  decoder.decode.bind(decoder);

export const esc = (cmd: string) => `\x1b${cmd}`;
export const csi = (cmd: string) => `\x1b[${cmd}`;
export const osc = (cmd: string) => `\x1b]${cmd}`;

export const query = async <T = Uint8Array>(
  cmd: string,
  {
    checker,
    transform,
    signal = AbortSignal.timeout(1000),
    readStream = process.stdin,
    writeStream = process.stdout,
  }: {
    transform?: (
      data: Uint8Array,
    ) => T | undefined;
    checker?: (data: NoInfer<T>) => boolean;
    signal?: AbortSignal;
    readStream?: ReadStream;
    writeStream?: WriteStream;
  } = {},
) =>
  new Promise<T>((resolve, reject) => {
    const handleData = (data: Buffer) => {
      const transformed = transform
        ? transform(new Uint8Array(data))
        : (data as T);
      if (typeof transformed === "undefined") {
        return;
      }
      if (checker) {
        if (checker(transformed)) {
          cleanup();
          resolve(transformed);
        }
      } else {
        cleanup();
        resolve(transformed);
      }
    };

    const handleAbort = () => {
      cleanup();
      reject(
        new Error(
          signal.reason ?? "Query aborted",
        ),
      );
    };

    const cleanup = () => {
      readStream.off("data", handleData);
      signal?.removeEventListener(
        "abort",
        handleAbort,
      );
    };

    const onEnd = () => {
      cleanup();
    };

    readStream.on("data", handleData);
    readStream.on("end", onEnd);

    if (signal) {
      if (signal.aborted) {
        handleAbort();
        return;
      }
      signal.addEventListener(
        "abort",
        handleAbort,
      );
    }

    writeStream.write(cmd);
  });
