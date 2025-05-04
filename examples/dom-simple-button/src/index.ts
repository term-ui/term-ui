import { initFromFile } from "@term-ui/core/node";
import { Document } from "@term-ui/dom";

const module = await initFromFile();

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
  timeout = setTimeout(() => {
    button.setText("Click me");
    document.render(true);
  }, 3000);
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
