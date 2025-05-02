import { createContext, use } from "react";
import type { TermUi } from "./TermUi.js";

export const TermUiContext =
  createContext<TermUi | null>(null);

export const useTermUi = () => {
  const termUi = use(TermUiContext);
  if (!termUi) {
    throw new Error("TermUiContext not found");
  }
  return termUi;
};
