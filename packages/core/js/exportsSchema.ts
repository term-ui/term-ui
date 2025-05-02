import { uniq, uniqueId } from "lodash-es";
import {
  type InferOutput,
  args,
  boolean,
  function_,
  instance,
  number,
  object,
  optional,
  pipe,
  returns,
  string,
  transform,
  tuple,
  union,
  unknown,
  void_,
} from "valibot";
import type { LogFn } from "./index.ts";
const encoder = new TextEncoder();

export const getSchema = (
  memory: WebAssembly.Memory,
  _instance: unknown,
  logFn: LogFn,
) => {
  const module = _instance as InferOutput<
    ReturnType<typeof getSchema>
  >;
  const catchError = <
    // biome-ignore lint/suspicious/noExplicitAny:
    T extends (...args: any[]) => any,
  >(
    name: string,
  ) =>
    transform<T, T>((fn: T) => {
      const callId = uniqueId("call_");
      return ((...args) => {
        try {
          // const trace = new Error().stack;
          // logFn({
          //   dt: Date.now(),
          //   pid: process.pid,
          //   level: "lifecycle",
          //   scope: name,
          //   message: `${callId} ${name}\n${trace}`,
          // });
          return fn(...args);
        } catch (e) {
          logFn({
            dt: Date.now(),
            pid: process.pid,
            level: "lifecycle",
            scope: name,
            message: `${callId} ${name} failed`,
          });
          throw e;
        }
      }) as T;
    });
  const booleanish = pipe(
    unknown(),
    transform((b) => !!b),
  );

  const zigString = pipe(
    string(),
    transform((str): number => {
      const buffer = encoder.encode(str);
      const bufferPtr =
        module.allocNullTerminatedBuffer(
          buffer.length,
        );
      const bufferArray = new Uint8Array(
        memory.buffer,
        bufferPtr,
        buffer.length,
      );
      bufferArray.set(buffer);
      return bufferPtr;
    }),
  );
  const zigBuffer = pipe(
    union([
      instance(ArrayBuffer),
      instance(Uint8Array),
    ]),
    transform((buffer): number => {
      const normalized =
        buffer instanceof Uint8Array
          ? buffer
          : new Uint8Array(buffer);

      const bufferPtr = module.allocBuffer(
        normalized.byteLength +
          Uint32Array.BYTES_PER_ELEMENT,
      );
      const bufferArray = new Uint8Array(
        memory.buffer,
        bufferPtr + Uint32Array.BYTES_PER_ELEMENT,
        normalized.byteLength,
      );
      const dataView = new DataView(
        memory.buffer,
      );
      dataView.setUint32(
        bufferPtr,
        normalized.byteLength,
        true,
      );

      bufferArray.set(normalized);
      return bufferPtr;
    }),
  );

  return object({
    Tree_init: pipe(
      function_(),
      args(tuple([])),
      returns(number()),
      catchError("Tree_init"),
    ),
    Tree_deinit: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("Tree_deinit"),
    ),
    Tree_createNode: pipe(
      function_(),
      args(tuple([number(), zigString])),
      returns(number()),
      catchError("Tree_createNode"),
    ),
    Tree_getNodeParent: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeParent"),
    ),
    Tree_createTextNode: pipe(
      function_(),
      args(tuple([number(), zigString])),
      returns(number()),
      catchError("Tree_createTextNode"),
    ),
    Tree_doesNodeExist: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(booleanish),
      catchError("Tree_doesNodeExist"),
    ),
    Tree_getNodeContains: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(booleanish),
      catchError("Tree_getNodeContains"),
    ),

    Tree_appendChild: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(void_()),
      catchError("Tree_appendChild"),
    ),

    Tree_insertBefore: pipe(
      function_(),
      args(
        tuple([
          number(),
          number(),
          number(),
          number(),
        ]),
      ),
      returns(void_()),
      catchError("Tree_insertBefore"),
    ),

    Tree_removeChild: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(void_()),
      catchError("Tree_removeChild"),
    ),

    Tree_removeChildren: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(void_()),
      catchError("Tree_removeChildren"),
    ),

    Tree_getChildrenCount: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getChildrenCount"),
    ),

    Tree_getNodeKind: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeKind"),
    ),

    Tree_appendChildAtIndex: pipe(
      function_(),
      args(
        tuple([
          number(),
          number(),
          number(),
          number(),
        ]),
      ),
      returns(void_()),
      catchError("Tree_appendChildAtIndex"),
    ),

    Tree_getChildren: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getChildren"),
    ),

    Tree_setStyle: pipe(
      function_(),
      args(
        tuple([number(), number(), zigString]),
      ),
      returns(void_()),
      catchError("Tree_setStyle"),
    ),

    Tree_setStyleProperty: pipe(
      function_(),
      args(
        tuple([
          number(),
          number(),
          zigString,
          zigString,
        ]),
      ),
      returns(void_()),
      catchError("Tree_setStyleProperty"),
    ),

    Tree_destroyNode: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(void_()),
      catchError("Tree_destroyNode"),
    ),

    Tree_destroyNodeRecursive: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(void_()),
      catchError("Tree_destroyNodeRecursive"),
    ),
    Tree_getNodeCursorStyle: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeCursorStyle"),
    ),

    Tree_getNodeScrollTop: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeScrollTop"),
    ),

    Tree_getNodeScrollLeft: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeScrollLeft"),
    ),

    Tree_setNodeScrollTop: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(void_()),
      catchError("Tree_setNodeScrollTop"),
    ),

    Tree_setNodeScrollLeft: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(void_()),
      catchError("Tree_setNodeScrollLeft"),
    ),

    Tree_getNodeScrollHeight: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeScrollHeight"),
    ),

    Tree_getNodeScrollWidth: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeScrollWidth"),
    ),

    Tree_getNodeClientHeight: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeClientHeight"),
    ),

    Tree_getNodeClientWidth: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("Tree_getNodeClientWidth"),
    ),

    Tree_dump: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
    ),

    Tree_setText: pipe(
      function_(),
      args(
        tuple([number(), number(), zigString]),
      ),
      returns(void_()),
      catchError("Tree_setText"),
    ),
    Tree_computeLayout: pipe(
      function_(),
      args(
        tuple([number(), zigString, zigString]),
      ),
      returns(void_()),
      catchError("Tree_computeLayout"),
    ),
    Tree_consumeEvents: pipe(
      function_(),
      args(
        tuple([
          number(),
          number(),
          optional(boolean(), false),
        ]),
      ),
      returns(number()),
      catchError("Tree_consumeEvents"),
    ),
    Tree_enableInputManager: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("Tree_enableInputManager"),
    ),
    Tree_disableInputManager: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("Tree_disableInputManager"),
    ),
    Renderer_init: pipe(
      function_(),
      args(tuple([])),
      returns(number()),
      catchError("Renderer_init"),
    ),
    Renderer_deinit: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("Renderer_deinit"),
    ),
    Renderer_renderToStdout: pipe(
      function_(),
      args(
        tuple([number(), number(), boolean()]),
      ),
      returns(void_()),
      catchError("Renderer_renderToStdout"),
    ),

    Renderer_getNodeAt: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(number()),
      catchError("Renderer_getNodeAt"),
    ),

    TermInfo_initFromMemory: pipe(
      function_(),
      args(tuple([zigBuffer])),
      returns(number()),
      catchError("TermInfo_initFromMemory"),
    ),
    TermInfo_deinit: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("TermInfo_deinit"),
    ),

    // InputManager_init: pipe(
    //   function_(),
    //   args(tuple([])),
    //   returns(number()),
    // ),
    // InputManager_deinit: pipe(
    //   function_(),
    //   args(tuple([number()])),
    //   returns(void_()),
    // ),

    ArrayList_init: pipe(
      function_(),
      args(tuple([])),
      returns(number()),
      catchError("ArrayList_init"),
    ),
    ArrayList_deinit: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("ArrayList_deinit"),
    ),
    ArrayList_appendUnusedSlice: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(number()),
      catchError("ArrayList_appendUnusedSlice"),
    ),
    ArrayList_clearRetainingCapacity: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError(
        "ArrayList_clearRetainingCapacity",
      ),
    ),
    ArrayList_getLength: pipe(
      function_(),
      args(tuple([number()])),
      returns(number()),
      catchError("ArrayList_getLength"),
    ),
    ArrayList_setLength: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(void_()),
      catchError("ArrayList_setLength"),
    ),
    ArrayList_getPointer: pipe(
      function_(),
      args(tuple([number()])),
      returns(number()),
      catchError("ArrayList_getPointer"),
    ),

    ArrayList_dump: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("ArrayList_dump"),
    ),

    allocBuffer: pipe(
      function_(),
      args(tuple([number()])),
      returns(number()),
      catchError("allocBuffer"),
    ),
    freeBuffer: pipe(
      function_(),
      args(tuple([number(), number()])),
      returns(void_()),
      catchError("freeBuffer"),
    ),
    allocNullTerminatedBuffer: pipe(
      function_(),
      args(tuple([number()])),
      returns(number()),
      catchError("allocNullTerminatedBuffer"),
    ),
    freeNullTerminatedBuffer: pipe(
      function_(),
      args(tuple([number()])),
      returns(void_()),
      catchError("freeNullTerminatedBuffer"),
    ),
    memcopy: pipe(
      function_(),
      args(tuple([number(), number(), number()])),
      returns(void_()),
      catchError("memcopy"),
    ),
    detectLeaks: pipe(
      function_(),
      args(tuple([])),
      returns(booleanish),
      catchError("detectLeaks"),
    ),

    EventBuffer: instance(WebAssembly.Global),
  });
};
