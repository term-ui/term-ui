/**
 * Constants for Selection operations
 */

/**
 * Direction for extending selection
 */
export const SelectionExtendDirection = {
  forward: 0,
  backward: 1,
} as const;

export type SelectionExtendDirection = typeof SelectionExtendDirection[keyof typeof SelectionExtendDirection];

/**
 * Granularity levels for selection movement
 */
export const SelectionExtendGranularity = {
  character: 0,
  word: 1,
  line: 2,
  lineBoundary: 3,
  documentBoundary: 4,
} as const;

export type SelectionExtendGranularity = typeof SelectionExtendGranularity[keyof typeof SelectionExtendGranularity];

/**
 * Selection direction values
 */
export const SelectionDirection = {
  forward: 1,
  backward: -1,
  none: 0,
} as const;

export type SelectionDirection = typeof SelectionDirection[keyof typeof SelectionDirection];

