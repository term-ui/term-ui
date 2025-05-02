# @term-ui/react

React bindings for Term UI - build beautiful, interactive terminal applications with React.

## Features

- **React for the Terminal**: Use React components to build terminal UIs
- **Custom Elements**: `<term-view>` and `<term-text>` components for terminal UI
- **Styling with React**: Use familiar inline styles with React syntax
- **Event Handling**: React event handling for terminal interactions
- **State Management**: Use React hooks and state management in the terminal
- **Composable**: Create reusable components for terminal UIs

## Demo

<p align="center">
  <a href="../docs/docs/assets/calculator-demo.mp4">
    <img src="https://github.com/term-ui/term-ui/assets/calculator-screenshot.png" alt="Calculator Demo (Click to view video)" width="600">
    <br>
    <em>Click to view calculator demo video</em>
  </a>
</p>

## Installation

```bash
# npm
npm install @term-ui/react

# pnpm
pnpm add @term-ui/react

# yarn
yarn add @term-ui/react
```

## Basic Usage

```tsx
import React, { useState } from 'react';
import TermUi from '@term-ui/react';

const App = () => {
  const [count, setCount] = useState(0);
  const [borderColor, setBorderColor] = useState('white');

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
      <term-text
        style={{
          color: 'magenta',
          bold: true,
        }}
      >
        Count: {count}
      </term-text>
      
      <term-view
        style={{
          borderStyle: 'double',
          padding: 1,
          cursor: 'pointer',
          borderColor: borderColor,
        }}
        onClick={() => setCount(count + 1)}
        onMouseEnter={() => setBorderColor('yellow')}
        onMouseLeave={() => setBorderColor('white')}
      >
        <term-text>Click to increment</term-text>
      </term-view>
    </term-view>
  );
};

// Render the app
TermUi.createRoot(<App />);
```

## Components

### `<term-view>`

Container component for creating layout structure.

Props:
- `style`: React style object
- Event handlers: `onClick`, `onMouseEnter`, `onMouseLeave`
- Children: Can contain other Term UI components

### `<term-text>`

Component for displaying text.

Props:
- `style`: React style object
- Children: String content to display

## Styling

Use familiar React inline styles:

```tsx
<term-view
  style={{
    width: '100%',
    height: 10,
    display: 'flex',
    borderStyle: 'rounded',
    borderColor: 'cyan',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    color: 'white',
    padding: 1,
    margin: 2,
  }}
>
  {/* Content */}
</term-view>
```

## Examples

### Calculator Example

The React binding enables complex applications like a fully-functional calculator:

```tsx
import React, { useState } from 'react';
import TermUi from '@term-ui/react';

const Calculator = () => {
  const [display, setDisplay] = useState('0');
  const [memory, setMemory] = useState(0);
  const [operation, setOperation] = useState('');
  
  const handleDigit = (digit) => {
    setDisplay(display === '0' ? digit : display + digit);
  };
  
  const handleOperation = (op) => {
    // Calculator logic
  };
  
  return (
    <term-view style={{ /* styles */ }}>
      <term-view style={{ /* display styles */ }}>
        {display}
      </term-view>
      
      <term-view style={{ /* keypad styles */ }}>
        {/* Calculator buttons */}
        <term-view onClick={() => handleDigit('1')}>1</term-view>
        {/* Other buttons */}
      </term-view>
    </term-view>
  );
};

TermUi.createRoot(<Calculator />);
```

Check out the [examples](https://github.com/yourusername/term-ui/tree/main/examples) directory for more complex examples and use cases.

## License

MIT
