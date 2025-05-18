import {
  initFromFile,
  distDir,
} from "@term-ui/core/node";
import { Document } from "@term-ui/dom";
import path from "node:path";
const module = await initFromFile(
  // path.join(distDir, "core-debug.wasm"), //
  undefined,
  {
    logFn: (log) => {
      // if (log.level === "error") {
      // console.error(log);
    },
  },
);

const document = new Document(module, {
  size: {
    width: "100%",
    height: "100%",
  },
});

// Set main container styles
document.root.setStyle(`
  color: white; 
  border-style: rounded; 
  padding: 1;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;

`);

const text = document.createTextNode(
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
);
document.root.appendChild(text);
const text2 = document.createTextNode(
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
);
document.root.appendChild(text2);
const bpNode = document.createTextNode("[]");

document.root.appendChild(bpNode);

// bpNode.setStyle(`

//   `);
const button = document.createElement("text");

button.setStyle(`
  border-style: double; 
  text-align: center;
  width: 30;
  border-color: white;
  cursor: pointer;
`);
button.setText("Click me");
document.root.appendChild(button);

let timeout: number;
button.addEventListener("click", () => {
  clearTimeout(timeout);
  button.setText("Thank you! 🎉");
  document.render(true);
  document.selection?.extendBy(
    "character",
    "forward",
  );
  timeout = setTimeout(() => {
    button.setText("Click me");
    document.render(true);
  }, 3000);
});

// document.root.addEventListener("click", (e) => {
//   const bp = document.caretPositionFromPoint(
//     e.x,
//     e.y,
//   );
//   if (bp) {
//     // bpNode.setText(JSON.stringify(bp));
//     document.render(true);
//   }
// });
// document.root.addEventListener(
//   "mouse-down",
//   (e) => {
//     const bp = document.caretPositionFromPoint(
//       e.x,
//       e.y,
//     );
//     if (!bp) return;
//     document.createSelection(bp);
//     bpNode.setText(JSON.stringify(bp));
//     document.render(true);
//   },
// );
let pressed = false;
const updateBpNode = () => {
  const selection = document.selection;

  const anchor = selection?.getAnchor();
  const focus = selection?.getFocus();
  const str = `[${anchor?.node ?? "null"}~${anchor?.offset ?? "null"}] [${focus?.node ?? "null"}~${focus?.offset ?? "null"}]`;
  bpNode.setText(str);
  document.render(true);
};
document.inputManager?.subscribe((e) => {
  if (e.kind !== "mouse") return;
  if (e.action === "press") {
    pressed = true;
    const bp = document.caretPositionFromPoint(
      e.x,
      e.y,
    );
    if (!bp) return;
    // console.log("bp", bp);
    document.createSelection(bp);
    document.render(true);

    // updateBpNode();
    updateBpNode();
  }
  if (e.action === "motion") {
    if (!pressed) return;
    const selection = document.selection;
    if (!selection) return;

    const bp = document.caretPositionFromPoint(
      e.x,
      e.y,
    );
    if (!bp) return;
    selection.setFocus(bp.node, bp.offset);
    updateBpNode();
    // updateBpNode();
  }
  if (e.action === "release") {
    pressed = false;
  }
});
button.addEventListener("mouse-enter", () => {
  button.setStyleProperty(
    "border-color",
    "radial-gradient(circle, cyan, magenta)",
  );
  document.render(true);
});

button.addEventListener("mouse-leave", () => {
  button.setStyleProperty(
    "border-color",
    "white",
  );
  document.render(true);
});

document.render(true);
