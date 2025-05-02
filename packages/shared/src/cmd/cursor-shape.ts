import { osc } from "./utils";

export const DEFAULT_CURSOR = 3;
export const cursorShapes = [
  "alias",

  "cell",

  "copy",

  "crosshair",

  "default",

  "e-resize",

  "ew-resize",

  "grab",

  "grabbing",

  "help",

  "move",

  "n-resize",

  "ne-resize",

  "nesw-resize",

  "no-drop",

  "not-allowed",

  "ns-resize",

  "nw-resize",

  "nwse-resize",

  "pointer",

  "progress",

  "s-resize",

  "se-resize",

  "sw-resize",

  "text",

  "vertical-text",

  "w-resize",

  "wait",

  "zoom-in",

  "zoom-out",
];
export type CursorShape =
  (typeof cursorShapes)[number];

export const cursorShape = (shape: CursorShape) =>
  osc(`22;${shape}\x1b\\`);
export const cursorShapeByInt = (shape: number) =>
  cursorShape(cursorShapes[shape] ?? "default");
