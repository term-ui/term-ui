# @term-ui/react

Term UI for React - build beautiful, interactive terminal applications with the tools you know. @term-ui/react makes hidden and overcomplicated terminal features as easy to use as building any other React app.
<p align="center">
  <img width="756" alt="Calculator demo" src="https://github.com/user-attachments/assets/4c374a9f-8b72-4a75-941c-213ddcfb7310" />
</p>

## Features

- **React for the Terminal**: Use React components to build terminal UIs
- **Advanced styling**: Use familiar styles with React syntax
- **Support for mouse events**: Builtin support for click, hover, scroll and other mouse events

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
