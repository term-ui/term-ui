import type { PropsWithChildren } from "react";
import type { TermUi } from "./TermUi";
import { TermUiContext } from "./term-ui-context";

export const Viewport = (
  props: PropsWithChildren<{
    termUi: TermUi;
  }>,
) => {
  return (
    <TermUiContext.Provider value={props.termUi}>
      {props.children}
    </TermUiContext.Provider>
  );
};
