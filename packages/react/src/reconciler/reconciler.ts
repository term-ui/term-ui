import {
  Document,
  type DomEvent,
  type Element,
  TextElement,
} from "@term-ui/dom";
import kebabCase from "lodash-es/kebabCase";
import createReconciler from "react-reconciler";
import {
  DefaultEventPriority,
  type EventPriority,
} from "react-reconciler/constants";
import type { TermUi } from "../TermUi";

const noop =
  <T>(value?: T) =>
  () =>
    value;
type ElementType = "term-text" | "term-view";
type Props = Record<string, unknown>;
type HostContext = {};
const NO_CONTEXT: HostContext = {};

// Types for event handling
type MouseEventName =
  | "click"
  | "mouse-enter"
  | "mouse-leave"
  | "mouse-move"
  | "mouse-down"
  | "mouse-up";
type EventHandler = (event: DomEvent) => void;

// Map from React prop names to DOM event names
const propToEventMap: Record<
  string,
  MouseEventName
> = {
  onClick: "click",
  onMouseEnter: "mouse-enter",
  onMouseLeave: "mouse-leave",
  onMouseMove: "mouse-move",
  onMouseDown: "mouse-down",
  onMouseUp: "mouse-up",
};

// Function to attach event handlers
const attachEventHandlers = (
  instance: Element,
  props: Props,
  oldProps?: Props,
) => {
  // instance.removeEventListener("scroll", oldProps?.onScroll);
  // For each possible event prop
  for (const [
    propName,
    eventName,
  ] of Object.entries(propToEventMap)) {
    const oldHandler = oldProps?.[propName] as
      | EventHandler
      | undefined;
    const newHandler = props[propName] as
      | EventHandler
      | undefined;

    // Remove old handler if it exists and is different from new handler
    if (oldHandler && oldHandler !== newHandler) {
      instance.removeEventListener(
        eventName,
        oldHandler,
      );
    }

    // Add new handler if it exists
    if (newHandler && newHandler !== oldHandler) {
      instance.addEventListener(
        eventName,
        newHandler,
      );
    }
  }
};

const stringifyStyles = (
  styles: Record<string, unknown>,
) => {
  return Object.entries(styles)
    .map(
      ([key, value]) =>
        `${kebabCase(key)}: ${value}`,
    )
    .join(";");
};

const normalizeStyle = (
  kind: ElementType,
  propStyles?: unknown,
) => {
  const styles: Record<string, unknown> = {};
  if (kind === "term-text") {
    return {
      display: "inline flow",
      ...(isPlainObject(propStyles)
        ? propStyles
        : {}),
    };
  }
  if (isPlainObject(propStyles)) {
    return {
      ...styles,
      ...propStyles,
    };
  }
  return styles;
};

// Store props on node instances
// class NodeWithProps extends BlockNode {
//   _props?: Props;
//   constructor(node: Node, props?: Props) {
//     super(node.tree, node.id);
//     this._props = props;
//   }
// }
const isPlainObject = (
  value: unknown,
): value is Record<string, unknown> => {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
};

let currentUpdatePriority: EventPriority =
  DefaultEventPriority;
export const reconciler = createReconciler(
  // new Reconciler(),
  {
    supportsMutation: true,
    supportsPersistence: false,
    supportsMicrotasks: true,

    isPrimaryRenderer: true,

    noTimeout: -1,
    scheduleTimeout: setTimeout,
    cancelTimeout: clearTimeout,

    createInstance: (
      type: ElementType,
      props: Props,
      termUi: TermUi,
      hostContext: HostContext,
      internalHandle: unknown,
    ) => {
      const styles = normalizeStyle(
        type,
        props?.style,
      );

      const style = stringifyStyles(styles);
      const node =
        termUi.document.createElement("view");
      node.setStyle(style);

      // Attach event handlers on instance creation
      attachEventHandlers(node, props);

      return node;
    },

    createTextInstance: (
      text: string,
      termUi: TermUi,
      hostContext: HostContext,
    ) => {
      // debug.log("createTextInstance", text);
      const node =
        termUi.document.createTextNode(text);
      return node;
    },
    scheduleMicrotask: queueMicrotask,
    getCurrentUpdatePriority: () =>
      currentUpdatePriority,

    resolveUpdatePriority: () =>
      currentUpdatePriority,
    setCurrentUpdatePriority: (priority) => {
      currentUpdatePriority = priority;
    },
    getPublicInstance: (instance) => instance,

    shouldSetTextContent: () => false,

    getRootHostContext: () => NO_CONTEXT,
    getChildHostContext: (parentContext) =>
      parentContext,
    finalizeInitialChildren: () => false,
    prepareForCommit: () => null,
    resetAfterCommit: (tui) => {
      tui.render();
    },
    detachDeletedInstance: (instance) => {
      if (instance.isDisposed()) {
        return true;
      }
      instance.disposeRecursively();
    },

    appendInitialChild: (parent, child) => {
      if (parent instanceof TextElement) {
        throw new Error(
          "appendInitialChild: parent is not a NodeWithProps",
        );
      }
      parent.appendChild(child);
    },

    appendChildToContainer: (tui, child) => {
      tui.document.root.appendChild(child);
    },
    appendChild: (parent, child) => {
      parent.appendChild(child);
    },
    insertBefore: (parent, child, before) => {
      parent.insertBefore(child, before);
    },
    removeChild: (parentInstance, child) => {
      if (parentInstance instanceof TextElement) {
        throw new Error(
          "removeChild: parentInstance is not a NodeWithProps",
        );
      }

      parentInstance.removeChild(child);
    },

    removeChildFromContainer: (tui, child) => {
      tui.document.root.removeChild(child);
    },

    clearContainer: (tui) => {
      tui.document.root.removeChildren();
    },
    resetTextContent(instance) {
      instance.setText("");
    },

    commitTextUpdate: (
      instance,
      oldText,
      newText,
    ) => {
      // debug.log(instance.id, newText, oldText);
      if (instance instanceof TextElement) {
        if (newText === oldText) {
          return;
        }
        // debug.log("setText", newText);
        instance.setText(newText);
        return;
      }
      throw new Error(
        "commitTextUpdate: instance is not a TextElement",
      );
    },

    commitUpdate: (
      instance,
      type,
      oldProps,
      newProps,
    ) => {
      // TODO: better diffing
      // if (instance instanceof TextNode) {
      //   return;
      // }

      const prevStyle = isPlainObject(
        oldProps?.style,
      )
        ? stringifyStyles(
            normalizeStyle(type, oldProps?.style),
          )
        : "";
      const newStyle = isPlainObject(
        newProps?.style,
      )
        ? stringifyStyles(
            normalizeStyle(type, newProps?.style),
          )
        : "";
      if (newStyle !== prevStyle) {
        instance.setStyle(newStyle);
      }

      // Attach/update event handlers
      attachEventHandlers(
        instance,
        newProps,
        oldProps,
      );
    },

    hideInstance: noop(false),
    unhideInstance: noop(false),

    maySuspendCommit: () => false,

    preloadInstance: noop(null),
    startSuspendingCommit: noop(),
    suspendInstance: noop(null),
    waitForCommitToBeReady: () => null,
  },
);
