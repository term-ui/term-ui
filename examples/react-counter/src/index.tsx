import TermUi from "@term-ui/react";
import {
  type PropsWithChildren,
  useState,
} from "react";

const VerticalSegment = ({
  x,
  y,
  on,
}: {
  x: number;
  y: number;
  on: boolean;
}) => {
  if (!on) {
    return null;
  }
  return (
    <term-text
      style={{
        position: "absolute",
        left: x,
        top: y,
      }}
    >
      {"█\n▀"}
    </term-text>
  );
};
const HorizontalSegment = ({
  x,
  y,
  on,
}: {
  x: number;
  y: number;
  on: boolean | 0 | 1;
}) => {
  if (!on) {
    return null;
  }
  return (
    <term-text
      style={{
        position: "absolute",
        left: x,
        top: y,
      }}
    >
      {"▄▄▄▄"}
    </term-text>
  );
};
const SEGMENT_MAP: Record<
  string,
  [
    a: number,
    b: number,
    c: number,
    d: number,
    e: number,
    f: number,
    g: number,
  ]
> = {
  // A B C D E F G,
  0: [1, 1, 1, 1, 1, 1, 0],
  1: [0, 1, 1, 0, 0, 0, 0],
  2: [1, 1, 0, 1, 1, 0, 1],
  3: [1, 1, 1, 1, 0, 0, 1],
  4: [0, 1, 1, 0, 0, 1, 1],
  5: [1, 0, 1, 1, 0, 1, 1],
  6: [1, 0, 1, 1, 1, 1, 1],
  7: [1, 1, 1, 0, 0, 0, 0],
  8: [1, 1, 1, 1, 1, 1, 1],
  9: [1, 1, 1, 1, 0, 1, 1],
  // To be able to display "ERR"
  E: [1, 0, 0, 1, 1, 1, 1],
  R: [1, 0, 0, 0, 1, 1, 0],
  // To be able to display "INF"
  I: [0, 1, 1, 0, 0, 0, 0],
  N: [1, 1, 1, 0, 1, 1, 0],
  F: [1, 0, 0, 0, 1, 1, 1],
  " ": [0, 0, 0, 0, 0, 0, 0],
  "-": [0, 0, 0, 0, 0, 0, 1],
  "*": [1, 1, 1, 1, 1, 1, 1],
  ".": [0, 0, 0, 0, 0, 0, 0],
} as const;

const SegmentDisplay = ({
  char,
  color = "rgba(255, 192, 203, 1)", // Default pink with full alpha
}: {
  char: keyof typeof SEGMENT_MAP;
  color?: string;
}) => {
  const [a, b, c, d, e, f, g] = SEGMENT_MAP[
    char
  ] ?? [0, 0, 0, 0, 0, 0, 0];
  if (char === ".") {
    return (
      <term-view
        style={{
          height: 5,
          width: 2,
        }}
      >
        {/* DP */}
        <term-text
          style={{
            position: "absolute",
            left: 1,
            top: 4,
            color,
          }}
        >
          {"▄"}
        </term-text>
      </term-view>
    );
  }
  return (
    <term-view
      style={{
        height: 5,
        width: 6,
        color,
      }}
    >
      {/* A */}
      <HorizontalSegment x={1} y={0} on={!!a} />
      {/* B */}
      <VerticalSegment x={5} y={1} on={!!b} />
      {/* C */}
      <VerticalSegment x={5} y={3} on={!!c} />
      {/* D */}
      <HorizontalSegment x={1} y={4} on={!!d} />
      {/* E */}
      <VerticalSegment x={0} y={3} on={!!e} />
      {/* F */}
      <VerticalSegment x={0} y={1} on={!!f} />
      {/* G */}
      <HorizontalSegment x={1} y={2} on={!!g} />
    </term-view>
  );
};

const SegmentDisplayPanel = ({
  number,
  color = "rgba(255, 192, 203, 1)", // Default pink with full alpha
}: {
  number: string;
  color?: string;
}) => {
  return (
    <term-view
      style={{
        display: "flex",
        flexDirection: "row",
        gap: 1,
      }}
    >
      {number.split("").map((char, i) => {
        const segmentChar =
          char as keyof typeof SEGMENT_MAP;
        return (
          <SegmentDisplay
            key={`${i}-${char}`}
            char={segmentChar}
            color={color}
          />
        );
      })}
    </term-view>
  );
};

const CalculatorButton = ({
  children,
  onClick,
  style,
  activeStyles = {
    backgroundColor: "rgba(255, 255, 255, 0.1)",
  },
  hoverStyles = {
    borderColor: "rgba(255, 255, 255, 1)",
    color: "rgba(255, 255, 255, 1)",
  },
}: PropsWithChildren<{
  onClick: () => void;
  activeStyles?: React.CSSProperties;
  hoverStyles?: React.CSSProperties;
  style?: React.CSSProperties;
}>) => {
  const [isActive, setIsActive] = useState(false);
  const [isHovered, setIsHovered] =
    useState(false);

  return (
    <term-view
      onMouseDown={() => setIsActive(true)}
      onMouseUp={() => setIsActive(false)}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      style={{
        height: 5,
        borderStyle: "rounded",
        borderWidth: 1,
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        fontWeight: "bold",
        flexGrow: 1,
        flexShrink: 0,
        flexBasis: "25%",
        color: "rgba(255, 255, 255, 0.8)",
        cursor: "pointer",
        borderColor:
          "linear-gradient(45deg, rgba(255, 255, 255, .8), rgba(255, 255, 255, 0.7))",
        ...(style ?? {}),
        ...(isHovered ? (hoverStyles ?? {}) : {}),
        ...(isActive ? (activeStyles ?? {}) : {}),
      }}
      onClick={onClick}
    >
      <term-text>{children}</term-text>
    </term-view>
  );
};
const Calculator = () => {
  const [display, setDisplay] = useState("0");
  const [storedValue, setStoredValue] = useState<
    number | null
  >(null);
  const [
    waitingForOperand,
    setWaitingForOperand,
  ] = useState(false);
  const [pendingOperator, setPendingOperator] =
    useState<string | null>(null);

  // Maximum number of characters to display
  const MAX_DISPLAY_LENGTH = 6;

  const calculate = (
    rightOperand: number,
    pendingOperator: string,
  ): number => {
    const leftOperand = storedValue ?? 0;

    switch (pendingOperator) {
      case "+":
        return leftOperand + rightOperand;
      case "-":
        return leftOperand - rightOperand;
      case "×":
        return leftOperand * rightOperand;
      case "÷":
        if (rightOperand === 0) {
          return Number.NaN;
        }
        return leftOperand / rightOperand;
      default:
        return rightOperand;
    }
  };

  // Convert numerical results to display strings
  const formatDisplayValue = (
    value: number,
  ): string => {
    if (Number.isNaN(value)) {
      return "ERR";
    }

    if (!Number.isFinite(value)) {
      return value > 0 ? "INF" : "-INF";
    }

    // Handle floating-point numbers with proper decimal place formatting
    const isFloat = value % 1 !== 0;
    if (isFloat) {
      // Convert to string first to check the integer part length
      const stringValue = `${value}`;
      const parts = stringValue.split(".");
      const integerPart = parts[0] || "";

      // Calculate how many decimal places we can display
      // Account for the decimal point itself in the calculation
      const maxDecimalPlaces =
        MAX_DISPLAY_LENGTH -
        integerPart.length -
        1;

      if (maxDecimalPlaces <= 0) {
        // No room for decimal places, check if integer part fits
        return integerPart.length >
          MAX_DISPLAY_LENGTH
          ? "ERR"
          : integerPart;
      }

      // Format with calculated decimal places
      const formattedValue = value.toFixed(
        maxDecimalPlaces,
      );

      // Trim trailing zeros while keeping at least one digit after decimal
      const trimmedValue = formattedValue
        .replace(/(\.\d*?)0+$/, "$1")
        .replace(/\.$/, "");

      // Check if the result still fits
      return trimmedValue.length >
        MAX_DISPLAY_LENGTH
        ? "ERR"
        : trimmedValue;
    }

    // For integers, just convert to string and check length
    const stringValue = `${value}`;
    return stringValue.length > MAX_DISPLAY_LENGTH
      ? "ERR"
      : stringValue;
  };

  const onClick = (button: string) => {
    switch (button) {
      case "AC": {
        setDisplay("0");
        setStoredValue(null);
        setWaitingForOperand(false);
        setPendingOperator(null);
        break;
      }

      case "+/-": {
        const value = Number.parseFloat(display);
        if (value !== 0) {
          setDisplay(
            value > 0
              ? `-${value}`
              : `${Math.abs(value)}`,
          );
        }
        break;
      }

      case "%": {
        const currentValue =
          Number.parseFloat(display);
        setDisplay(`${currentValue / 100}`);
        setWaitingForOperand(true);
        break;
      }

      case "+":
      case "-":
      case "×":
      case "÷": {
        const operand =
          Number.parseFloat(display);

        if (
          pendingOperator !== null &&
          !waitingForOperand
        ) {
          const result = calculate(
            operand,
            pendingOperator,
          );
          setDisplay(formatDisplayValue(result));
          setStoredValue(
            Number.isFinite(result)
              ? result
              : null,
          );
        } else {
          setStoredValue(operand);
        }

        setPendingOperator(button);
        setWaitingForOperand(true);
        break;
      }

      case "=": {
        if (pendingOperator === null) {
          return;
        }

        const operand2 =
          Number.parseFloat(display);
        const result = calculate(
          operand2,
          pendingOperator,
        );

        setDisplay(formatDisplayValue(result));
        setStoredValue(
          Number.isFinite(result) ? result : null,
        );
        setPendingOperator(null);
        setWaitingForOperand(true);
        break;
      }

      case ".": {
        if (waitingForOperand) {
          setDisplay("0.");
          setWaitingForOperand(false);
        } else if (
          !display.includes(".") &&
          display.length < MAX_DISPLAY_LENGTH
        ) {
          setDisplay(`${display}.`);
        }
        break;
      }

      default: {
        // Digits 0-9
        const digit = button;

        if (waitingForOperand) {
          setDisplay(digit);
          setWaitingForOperand(false);
        } else {
          // Don't add more digits if we've reached the maximum length
          if (
            display.length >= MAX_DISPLAY_LENGTH
          ) {
            break;
          }

          setDisplay(
            display === "0"
              ? digit
              : `${display}${digit}`,
          );
        }
        break;
      }
    }
  };
  const lastColumnColor =
    "rgba(142, 81, 255, 0.2)";

  return (
    <term-view
      style={{
        width: "100%",
        display: "flex",
        maxWidth: 52,
        height: 39,
        margin: "auto",
        borderStyle: "rounded",
        flexDirection: "column",
        backgroundColor:
          "rgba(255, 255, 255, 0.05)",
        padding: "1",
      }}
    >
      <term-text
        style={{
          position: "absolute",
          top: 0,
          right: 2,
          color: "rgba(255, 255, 255, 0.6)",
        }}
      >
        @term-ui/react
      </term-text>
      <term-view
        style={{
          padding: "1",
          backgroundColor:
            "rgba(255, 255, 255, 0.1)",
          borderStyle: "rounded",
          display: "flex",

          flexDirection: "row",
          justifyContent: "end",
          gap: 1,
          flexWrap: "wrap",
        }}
      >
        <SegmentDisplayPanel
          number={display}
          color={
            waitingForOperand
              ? "rgba(255, 192, 203, 0.8)"
              : "rgba(255, 192, 203, 1)"
          }
        />
      </term-view>
      <term-view
        style={{
          display: "flex",
          flexDirection: "row",
          // gap: 1,
        }}
      >
        {["AC", "+/-", "%", "÷"].map(
          (text, i) => (
            <CalculatorButton
              key={text}
              onClick={() => onClick(text)}
              style={
                i === 3
                  ? {
                      backgroundColor:
                        lastColumnColor,
                    }
                  : {}
              }
            >
              {text}
            </CalculatorButton>
          ),
        )}
      </term-view>
      <term-view
        style={{
          display: "flex",
        }}
      >
        {["7", "8", "9", "×"].map((text, i) => (
          <CalculatorButton
            key={text}
            onClick={() => onClick(text)}
            style={
              i === 3
                ? {
                    backgroundColor:
                      lastColumnColor,
                  }
                : {}
            }
          >
            {text}
          </CalculatorButton>
        ))}
      </term-view>
      <term-view
        style={{
          display: "flex",
        }}
      >
        {["4", "5", "6", "-"].map((text, i) => (
          <CalculatorButton
            key={text}
            onClick={() => onClick(text)}
            style={
              i === 3
                ? {
                    backgroundColor:
                      lastColumnColor,
                  }
                : {}
            }
          >
            {text}
          </CalculatorButton>
        ))}
      </term-view>
      <term-view
        style={{
          display: "flex",
        }}
      >
        {["1", "2", "3", "+"].map((text, i) => (
          <CalculatorButton
            key={text}
            onClick={() => onClick(text)}
            style={
              i === 3
                ? {
                    backgroundColor:
                      lastColumnColor,
                  }
                : {}
            }
          >
            {text}
          </CalculatorButton>
        ))}
      </term-view>
      <term-view
        style={{
          display: "flex",
        }}
      >
        {["", "0", ".", "="].map((text, i) => (
          <CalculatorButton
            key={text}
            onClick={() => onClick(text)}
            style={
              i === 3
                ? {
                    backgroundColor:
                      lastColumnColor,
                  }
                : {}
            }
          >
            {text}
          </CalculatorButton>
        ))}
      </term-view>
    </term-view>
  );
};

const App = () => {
  return (
    <term-view
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        overflow: "scroll",
        padding: "1",
        backgroundColor:
          "radial-gradient(circle at top left,rgba(10, 10, 10, 1), rgba(252, 70, 107, .05))",
      }}
    >
      <Calculator />
    </term-view>
  );
};

await TermUi.createRoot(<App />, {});
