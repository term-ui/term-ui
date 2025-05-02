import type {
  TermTextProps,
  TermViewProps,
} from "./types";

declare global {
  namespace React {
    namespace JSX {
      interface Term {
        view: React.DetailedHTMLProps<
          React.HTMLAttributes<HTMLElement>,
          HTMLElement
        >;
      }
      interface IntrinsicElements {
        "term-view": TermViewProps;
        "term-text": TermTextProps;
      }
    }
  }
}
export * from "./TermUi";
export { TermUi as default } from "./TermUi";
