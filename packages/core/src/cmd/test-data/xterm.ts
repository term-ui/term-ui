export interface ICoreMouseEvent {
  /** column (zero based). */
  col: number;
  /** row (zero based). */
  row: number;
  /** xy pixel positions. */
  x: number;
  y: number;
  /**
   * Button the action occured. Due to restrictions of the tracking protocols
   * it is not possible to report multiple buttons at once.
   * Wheel is treated as a button.
   * There are invalid combinations of buttons and actions possible
   * (like move + wheel), those are silently ignored by the CoreMouseService.
   */
  button: number;
  action: number;
  /**
   * Modifier states.
   * Protocols will add/ignore those based on specific restrictions.
   */
  ctrl?: boolean;
  alt?: boolean;
  shift?: boolean;
}
export const CoreMouseButton = {
  LEFT: 0,
  MIDDLE: 1,
  RIGHT: 2,
  NONE: 3,
  WHEEL: 4,
  // additional buttons 1..8
  // untested!
  AUX1: 8,
  AUX2: 9,
  AUX3: 10,
  AUX4: 11,
  AUX5: 12,
  AUX6: 13,
  AUX7: 14,
  AUX8: 15,
};
const Modifiers = {
  SHIFT: 4,
  ALT: 8,
  CTRL: 16,
};
export const CoreMouseAction = {
  UP: 0, // buttons, wheel
  DOWN: 1, // buttons, wheel
  LEFT: 2, // wheel only
  RIGHT: 3, // wheel only
  MOVE: 32, // buttons only
};

// helper for default encoders to generate the event code.
function eventCode(
  e: ICoreMouseEvent,
  isSGR: boolean,
): number {
  let code =
    (e.ctrl ? Modifiers.CTRL : 0) |
    (e.shift ? Modifiers.SHIFT : 0) |
    (e.alt ? Modifiers.ALT : 0);
  if (e.button === CoreMouseButton.WHEEL) {
    code |= 64;
    code |= e.action;
  } else {
    code |= e.button & 3;
    if (e.button & 4) {
      code |= 64;
    }
    if (e.button & 8) {
      code |= 128;
    }
    if (e.action === CoreMouseAction.MOVE) {
      code |= CoreMouseAction.MOVE;
    } else if (
      e.action === CoreMouseAction.UP &&
      !isSGR
    ) {
      // special case - only SGR can report button on release
      // all others have to go with NONE
      code |= CoreMouseButton.NONE;
    }
  }
  return code;
}

const S = String.fromCharCode;

/**
 *
 * Supported default encodings.
 */
const DEFAULT_ENCODINGS = {
  /**
   * DEFAULT - CSI M Pb Px Py
   * Single byte encoding for coords and event code.
   * Can encode values up to 223 (1-based).
   */
  DEFAULT: (e: ICoreMouseEvent) => {
    const params = [
      eventCode(e, false) + 32,
      e.col + 32,
      e.row + 32,
    ];
    // supress mouse report if we exceed addressible range
    // Note this is handled differently by emulators
    // - xterm:         sends 0;0 coords instead
    // - vte, konsole:  no report
    if (
      params[0] > 255 ||
      params[1] > 255 ||
      params[2] > 255
    ) {
      return "";
    }
    return `\x1b[M${S(params[0])}${S(params[1])}${S(params[2])}`;
  },
  /**
   * SGR - CSI < Pb ; Px ; Py M|m
   * No encoding limitation.
   * Can report button on release and works with a well formed sequence.
   */
  SGR: (e: ICoreMouseEvent) => {
    const final =
      e.action === CoreMouseAction.UP &&
      e.button !== CoreMouseButton.WHEEL
        ? "m"
        : "M";
    return `\x1b[<${eventCode(e, true)};${e.col};${e.row}${final}`;
  },
  SGR_PIXELS: (e: ICoreMouseEvent) => {
    const final =
      e.action === CoreMouseAction.UP &&
      e.button !== CoreMouseButton.WHEEL
        ? "m"
        : "M";
    return `\x1b[<${eventCode(e, true)};${e.x};${e.y}${final}`;
  },
};

const emit = (
  encoding: keyof typeof DEFAULT_ENCODINGS,
  e: Partial<ICoreMouseEvent>,
) => {
  console.log(
    JSON.stringify(
      DEFAULT_ENCODINGS[encoding]({
        action: CoreMouseAction.DOWN,
        button: CoreMouseButton.LEFT,
        col: 0,
        row: 0,
        x: 0,
        y: 0,
        ctrl: false,
        alt: false,
        shift: false,
        ...e,
      }),
      null,
      2,
    ),
  );
};

emit("DEFAULT", {
  action: CoreMouseAction.UP,
  button: CoreMouseButton.MIDDLE,
  col: 200,
  row: 200,
  // ctrl: true,
  // alt: true,
  // shift: true,
});
