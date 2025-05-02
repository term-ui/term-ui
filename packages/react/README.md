# @term-ui/react

[![npm version](https://img.shields.io/npm/v/@term-ui/react)](https://www.npmjs.com/package/@term-ui/react) [![MIT License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Build beautiful, interactive terminal applications with React. Leverage familiar React components and styling patterns to harness the power of the terminal—no more wrestling with low‑level ANSI codes.

<p align="center">
  <img width="756" alt="Calculator demo" src="https://github.com/user-attachments/assets/4c374a9f-8b72-4a75-941c-213ddcfb7310" />
</p>

> **⚠️ Alpha Status**: Term UI is currently in alpha. The API is unstable and subject to change. You may encounter bugs during use.
>
> **📺 Terminal Compatibility**: Some features depend on terminal capabilities and may not work in all terminal emulators. In the future, we plan to provide an easy-to-use API for detecting these features so applications can gracefully fallback when needed.

---

## 📖 Table of Contents

* [✨ Features](#-features)
* [⚙️ Installation](#️-installation)
* [🚀 Quick Start](#-quick-start)
* [🧩 API Reference](#-api-reference)

  * [`<term-view>`](#term-view)
  * [`<term-text>`](#term-text)
* [🎨 Styling](#-styling)
* [🖥️ Examples](#️-examples)
* [📝 Contributing](#-contributing)
* [📄 License](#-license)

---

## ✨ Features

* **React for the Terminal**: Build terminal UIs with React components and hooks.
* **React 19 Support**: Compatible with the latest React version.
* **Flexbox Layout**: Arrange elements with `display: 'flex'`, `flexDirection`, `justifyContent`, and `alignItems`.
* **Styling**: Inline styles support colors, borders, padding, margin, and background.
* **Color Compositing**: Use full RGBA color values for backgrounds, borders, and text.
  \$1
* **Built with Zig, WebAssembly & TypeScript**: Zig and WebAssembly for performance, TypeScript and React for developer convenience.

---

## ⚙️ Installation

```bash
# npm
npm install @term-ui/react

# pnpm
pnpm add @term-ui/react

# bun
bun install @term-ui/react

# yarn
yarn add @term-ui/react

```

---

## 🚀 Quick Start

```tsx
import React, { useState } from 'react';
import TermUi from '@term-ui/react';

const App = () => {
  const [count, setCount] = useState(0);
  const [borderColor, setBorderColor] = useState('gray');

  return (
    <term-view
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 2,
        gap: 1,
        borderStyle: 'rounded',
        borderColor: 'cyan',
      }}
    >
      <term-text style={{ color: 'cyan', bold: true }}>Count: {count}</term-text>

      <term-view
        style={{
          borderStyle: 'double',
          padding: 1,
          cursor: 'pointer',
          borderColor,
        }}
        onClick={() => setCount(count + 1)}
        onMouseEnter={() => setBorderColor('pink')}
        onMouseLeave={() => setBorderColor('gray')}
      >
        <term-text>Click to increment</term-text>
      </term-view>
    </term-view>
  );
};

TermUi.createRoot(<App />);
```

---

## 🧩 API Reference

### `<term-view>`

The primary container component. Use it to build layouts and capture events.

| Prop           | Type                |
| -------------- | ------------------- |
| `style`        | React.CSSProperties |
| `onClick`      | `(event: MouseClickEvent) => void` |
| `onMouseEnter` | `(event: MouseEnterEvent) => void` |
| `onMouseLeave` | `(event: MouseLeaveEvent) => void` |
| `onMouseMove`  | `(event: MouseMoveEvent) => void` |
| `onMouseDown`  | `(event: MouseDownEvent) => void` |
| `onMouseUp`    | `(event: MouseUpEvent) => void` |
| `onScroll`     | `(event: ScrollEvent) => void` |
| `children`     | `ReactNode` |

### `<term-text>`

Text rendering component. Supports styling props for typography.

| Prop       | Type                |
| ---------- | ------------------- |
| `style`    | React.CSSProperties |
| `children` | `ReactNode` |

---

## 🎨 Styling

Term UI uses inline style objects:

```tsx
<term-view
  style={{
    width: 40,
    height: 5,
    display: 'flex',
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    borderStyle: 'rounded',
    borderColor: 'cyan',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    color: 'white',
    padding: 1,
    margin: 2,
    cursor: 'pointer',
  }}
>
  <term-text style={{ fontWeight: 'bold', textDecoration: 'underline' }}>Hello, Terminal!</term-text>
</term-view>
```

Supported style properties:

| Property | Accepted Values |
|----------|----------------|
| `display` | `'flex'`, `'block'`, `'inline-block'`, `'inline-flex'`, `'none'`, `'inline'` |
| `position` | `'relative'`, `'absolute'` |
| `width`, `height` | Numbers, percentages (e.g., `'50%'`), `'auto'` |
| `minWidth`, `minHeight` | Numbers, percentages (e.g., `'50%'`), `'auto'` |
| `maxWidth`, `maxHeight` | Numbers, percentages (e.g., `'50%'`), `'auto'` |
| `top`, `right`, `bottom`, `left` | Numbers, percentages (e.g., `'50%'`), `'auto'` |
| `margin`, `marginTop`, `marginRight`, `marginBottom`, `marginLeft` | Numbers, percentages, `'auto'` |
| `padding`, `paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft` | Numbers, percentages |
| `overflow`, `overflowX`, `overflowY` | `'visible'`, `'hidden'`, `'clip'`, `'scroll'` |
| `flexDirection` | `'row'`, `'column'`, `'row-reverse'`, `'column-reverse'` |
| `flexWrap` | `'no-wrap'`, `'wrap'`, `'wrap-reverse'` |
| `flexBasis` | Numbers, percentages, `'auto'` |
| `flexGrow`, `flexShrink` | Numbers |
| `alignItems`, `alignSelf`, `justifyItems`, `justifySelf` | `'start'`, `'end'`, `'flex-start'`, `'flex-end'`, `'center'`, `'baseline'`, `'stretch'` |
| `alignContent`, `justifyContent` | `'start'`, `'end'`, `'flex-start'`, `'flex-end'`, `'center'`, `'stretch'`, `'space-between'`, `'space-around'`, `'space-evenly'` |
| `gap` | Numbers, percentages |
| `textAlign` | `'start'`, `'end'`, `'left'`, `'right'`, `'center'`, `'inherit'` |
| `textWrap` | `'wrap'`, `'nowrap'`, `'inherit'` |
| `fontWeight` | `'normal'`, `'bold'`, `'dim'`, `'inherit'` |
| `fontStyle` | `'normal'`, `'italic'`, `'inherit'` |
| `textDecoration` | `'none'`, `'underline'`, `'double'`, `'dashed'`, `'line-through'`, `'wavy'`, `'inherit'` |
| `color` | Named colors (all CSS colors supported), hex values (`'#ff0000'`), RGB/RGBA values |
| `backgroundColor`, `borderColor` | Named colors (all CSS colors supported), hex values (`'#ff0000'`), RGB/RGBA values, `'linear-gradient(...)'`, `'radial-gradient(...)'` |
| `borderStyle` | `'none'`, `'solid'`, `'heavy'`, `'double'`, `'rounded'`, `'dashed'`/`'dashed-double'`, `'dashed-double-heavy'`, `'dashed-wide'`, `'dashed-wide-heavy'`, `'dashed-triple'`, `'dashed-triple-heavy'`, `'dashed-quadruple'`, `'dashed-quadruple-heavy'` |
| `cursor` | `'alias'`, `'cell'`, `'copy'`, `'crosshair'`, `'default'`, `'e-resize'`, `'ew-resize'`, `'grab'`, `'grabbing'`, `'help'`, `'move'`, `'n-resize'`, `'ne-resize'`, `'nesw-resize'`, `'no-drop'`, `'not-allowed'`, `'ns-resize'`, `'nw-resize'`, `'nwse-resize'`, `'pointer'`, `'progress'`, `'s-resize'`, `'se-resize'`, `'sw-resize'`, `'text'`, `'vertical-text'`, `'w-resize'`, `'wait'`, `'zoom-in'`, `'zoom-out'` |

**Color Support:**
- Named colors: Supports all CSS named colors including `'white'`, `'black'`, `'red'`, `'green'`, `'blue'`, `'cyan'`, `'magenta'`, `'yellow'`, etc.
- Hex: `'#ff0000'`, `'#f00'`
- RGB/RGBA: `'rgb(255, 0, 0)'`, `'rgba(255, 0, 0, 0.5)'`
- Gradients: `'linear-gradient(to right, red, blue)'`, `'radial-gradient(circle, yellow, green)'` 

**Size Units:**
- Numbers are interpreted as character cells: `width: 10` (10 characters wide)
- Percentages refer to parent container: `width: '50%'`
- `'auto'` for automatic sizing (flexbox)
- `'px'` units are supported but treated as equivalent to 1 character cell (e.g., `width: '20px'` is the same as `width: 20`)

**Border Styles:**
- `'none'`: No border
- `'solid'`: Light solid border
- `'heavy'`: Heavy solid border
- `'double'`: Double-line border
- `'rounded'`: Rounded corner border
- `'dashed'` or `'dashed-double'`: Light double-dashed border
- `'dashed-double-heavy'`: Heavy double-dashed border
- `'dashed-wide'`: Light widely-spaced dashed border
- `'dashed-wide-heavy'`: Heavy widely-spaced dashed border
- `'dashed-triple'`: Light triple-dashed border
- `'dashed-triple-heavy'`: Heavy triple-dashed border
- `'dashed-quadruple'`: Light quadruple-dashed border
- `'dashed-quadruple-heavy'`: Heavy quadruple-dashed border

**Cursor Styles:**
- `'alias'`
- `'cell'`
- `'copy'`
- `'crosshair'`
- `'default'`
- `'e-resize'`
- `'ew-resize'`
- `'grab'`
- `'grabbing'`
- `'help'`
- `'move'`
- `'n-resize'`
- `'ne-resize'`
- `'nesw-resize'`
- `'no-drop'`
- `'not-allowed'`
- `'ns-resize'`
- `'nw-resize'`
- `'nwse-resize'`
- `'pointer'`
- `'progress'`
- `'s-resize'`
- `'se-resize'`
- `'sw-resize'`
- `'text'`
- `'vertical-text'`
- `'w-resize'`
- `'wait'`
- `'zoom-in'`
- `'zoom-out'`

---

## 🗺️ Roadmap

Here are some features and improvements we're planning for future releases:

* **Element Focus Management**: Keyboard navigation and focus control between elements
* **Form Inputs**: Native form components like text inputs, checkboxes, and select menus
* **Built-in State Selectors**: CSS-like `:hover` and `:active` state selectors for styling without JavaScript state tracking
* **Advanced Styling System**: Class-based styling with CSS selectors for targeting children and siblings, with improved style cascading.
* **DevTools**: Developer tools for inspecting and debugging terminal UI applications
* **Build Tools**: Optimized build configurations for terminal applications
* **Hot Reloading**: Support for hot module replacement during development

---

## 📄 License

Released under the MIT License. See [LICENSE](LICENSE) for details.
