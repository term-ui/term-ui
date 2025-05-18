import type {
  ReadStream,
  WriteStream,
} from "@term-ui/shared/types";
import type { Document } from "./Document";
import type { Element } from "./Element";
import type { KeyName } from "./InputManager";

export type Size<T = number> = {
  width: T;
  height: T;
};
export type DomEvent =
  | MouseEnterEvent
  | MouseLeaveEvent
  | MouseMoveEvent
  | MouseDownEvent
  | MouseUpEvent
  | MouseClickEvent
  | ScrollEvent
  | KeydownEvent
  | KeyupEvent
  | KeypressEvent;
export type MouseEnterEvent = {
  kind: "mouse-enter";
  target: Element;
  document: Document;
};
export type MouseLeaveEvent = {
  kind: "mouse-leave";
  target: Element;
  document: Document;
};
export type MouseMoveEvent = {
  kind: "mouse-move";
  target: Element;
  document: Document;
  x: number;
  y: number;
};
export type MouseDownEvent = {
  kind: "mouse-down";
  target: Element;
  document: Document;
  x: number;
  y: number;
};
export type MouseUpEvent = {
  kind: "mouse-up";
  target: Element;
  document: Document;
  x: number;
  y: number;
};
export type MouseClickEvent = {
  kind: "click";
  target: Element;
  document: Document;
  x: number;
  y: number;
};
export type ScrollEvent = {
  kind: "scroll";
  target: Element;
  document: Document;
  deltaX: number;
  deltaY: number;
  preventDefault: () => void;
};

export type BaseKeyEvent = {
  target: Element;
  document: Document;
  key?: KeyName;
  codepoint: number;
  text: string;
  shift: boolean;
  ctrl: boolean;
  alt: boolean;
  super: boolean;
  meta: boolean;
  repeat?: boolean;
  preventDefault: () => void;
};

export type KeydownEvent = BaseKeyEvent & {
  kind: "keydown";
};

export type KeyupEvent = BaseKeyEvent & {
  kind: "keyup";
};

export type KeypressEvent = BaseKeyEvent & {
  kind: "keypress";
};

export type RenderingSize = Size<
  | number
  | "min-content"
  | "max-content"
  | `${number}%`
>;
export type DocumentOptions = {
  writeStream: WriteStream;
  readStream: ReadStream;
  size: RenderingSize;
  reportLeaksOnExit: boolean;
  enableInputs: boolean;
  exitOnCtrlC: boolean;
  enableAlternateScreen: boolean;
  clearScreenBeforePaint: boolean;
  onPaintRequest?: () => void;
};
