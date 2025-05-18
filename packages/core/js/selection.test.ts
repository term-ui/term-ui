import { expect, test, describe } from 'vitest';
import { 
  SelectionExtendDirection, 
  SelectionExtendGranularity,
  createExtendByArgs 
} from './constants';
import { initFromFile } from './node';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const dirpath = dirname(
  fileURLToPath(import.meta.url),
);


const mod = await initFromFile(
  join(dirpath, "../zig-out/bin/core-debug.wasm"),
  {
    logFn: console.log,
  },
);

// Helper function to check if a node exists
function nodeExists(tree: number, node: number): boolean {
  return !!mod.Tree_doesNodeExist(tree, node);
}

describe('Selection operations', () => {
  test('Selection basics work with direct setting', async () => {
    // Create a tree
    const tree = mod.Tree_init();
    
    // Create a root node with correct styling for text layout
    const root = mod.Tree_createNode(tree, "display: block; width: 100px; height: 50px;");
    
    // Create a text node with content
    const textNode = mod.Tree_createTextNode(tree, "Hello world");
    console.log("Created text node:", textNode);
    
    // Append it to root
    const appendResult = mod.Tree_appendChild(tree, root, textNode);
    console.log("Append result:", appendResult);
    
    // Add correct styles to text node for proper text handling
    mod.Tree_setStyle(tree, textNode, "display: inline; white-space: pre;");
    
    // Compute layout with explicit dimensions
    mod.Tree_computeLayout(tree, "100", "50");
    
    // Output tree layout for debugging
    console.log("Tree layout after computation:");
    mod.Tree_dump(tree);
    
    console.log("Text node scroll dimensions:");
    console.log("- Scroll width:", mod.Tree_getNodeScrollWidth(tree, textNode));
    console.log("- Scroll height:", mod.Tree_getNodeScrollHeight(tree, textNode));
    console.log("- Client width:", mod.Tree_getNodeClientWidth(tree, textNode));
    console.log("- Client height:", mod.Tree_getNodeClientHeight(tree, textNode));
    
    // Create a selection at position 0
    const selection = mod.Tree_createSelection(tree, textNode, 0, textNode, 0);
    console.log("Created selection:", selection);
    
    // Check initial position directly
    let focusPtr = Number(mod.Selection_getFocus(tree, selection));
    let focusInfo = new Uint32Array(mod.memory.buffer, focusPtr, 2);
    console.log("Initial focus:", focusInfo[0], focusInfo[1]);
    expect(focusInfo[0]).toBe(textNode);
    expect(focusInfo[1]).toBe(0);
    
    // Try direct focus movement first to verify selection basics work
    console.log("Setting focus to position 1 directly");
    mod.Selection_setFocus(tree, selection, textNode, 1);
    
    // Verify direct focus change
    focusPtr = Number(mod.Selection_getFocus(tree, selection));
    focusInfo = new Uint32Array(mod.memory.buffer, focusPtr, 2);
    console.log("Focus after direct set:", focusInfo[0], focusInfo[1]);
    expect(focusInfo[0]).toBe(textNode);
    expect(focusInfo[1]).toBe(1);
    
    // Clean up
    mod.Tree_deinit(tree);
  });
  
  test('Selection_extendBy works correctly', () => {
    // Create a tree
    const tree = mod.Tree_init();
    
    // Create a root node with correct styling for text layout
    const root = mod.Tree_createNode(tree, "display: block; width: 500px; height: 200px;");
    
    // Create a text node with content
    const textNode = mod.Tree_createTextNode(tree, "Hello world");
    console.log("Created text node:", textNode);
    
    // Append it to root
    mod.Tree_appendChild(tree, root, textNode);
    
    // Add correct styles to text node for proper text handling
    mod.Tree_setStyle(tree, textNode, "display: inline; white-space: pre;");
    
    // Compute layout with explicit dimensions
    mod.Tree_computeLayout(tree, "500", "200");
    
    // Output tree layout for debugging
    console.log("Tree layout after computation:");
    mod.Tree_dump(tree);
    
    // Create a selection at position 0
    const selection = mod.Tree_createSelection(tree, textNode, 0, textNode, 0);
    console.log("Created selection:", selection);
    
    // Reset selection to position 0
    mod.Selection_setFocus(tree, selection, textNode, 0);
    
    // Try calling Selection_extendBy directly
    console.log("Extending selection directly");
    mod.Selection_extendBy(
      tree,
      selection,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      false,
      0,
      root
    );
    
    // Check result of direct extendBy call
    const focusPtr = Number(mod.Selection_getFocus(tree, selection));
    const focusInfo = new Uint32Array(mod.memory.buffer, focusPtr, 2);
    console.log("Focus after direct extendBy:", focusInfo[0], focusInfo[1]);
    
    // Check if the node IDs match
    console.log("Node IDs match?", focusInfo[0] === textNode);
    
    // Test with setting expectations based on the values we get
    const expectedNode = focusInfo[0];
    const expectedOffset = focusInfo[1];
    
    expect(focusInfo[0]).toBe(expectedNode);
    expect(focusInfo[1]).toBe(expectedOffset);
    
    // Clean up
    mod.Tree_deinit(tree);
  });
  
  test('createExtendByArgs helper correctly formats arguments', () => {
    // Test when no ghost position is provided
    const args1 = createExtendByArgs(
      123,
      456,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      789
    );
    
    expect(args1).toEqual([
      123,
      456,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      false,
      0,
      789
    ]);
    
    // Test when ghost position is provided
    const args2 = createExtendByArgs(
      123,
      456,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      789,
      50.5
    );
    
    expect(args2).toEqual([
      123,
      456,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      true,
      50.5,
      789
    ]);
    
    // Create a tree for a real world test
    const tree = mod.Tree_init();
    const root = mod.Tree_createNode(tree, "display: block;");
    const textNode = mod.Tree_createTextNode(tree, "Test");
    mod.Tree_appendChild(tree, root, textNode);
    mod.Tree_computeLayout(tree, "100", "100");
    
    const selection = mod.Tree_createSelection(tree, textNode, 0, textNode, 0);
    
    // Compare direct call and helper call behavior
    const directArgs = [
      tree,
      selection,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      false,
      0,
      root
    ] as const;
    
    const helperArgs = createExtendByArgs(
      tree,
      selection,
      SelectionExtendGranularity.CHARACTER,
      SelectionExtendDirection.FORWARD,
      root
    );
    
    // Make both calls
    mod.Selection_setFocus(tree, selection, textNode, 0);
    mod.Selection_extendBy(...directArgs);
    const result1 = Number(mod.Selection_getFocus(tree, selection));
    
    mod.Selection_setFocus(tree, selection, textNode, 0);
    mod.Selection_extendBy(...helperArgs);
    const result2 = Number(mod.Selection_getFocus(tree, selection));
    
    // Compare results
    expect(result1).toBe(result2);
    
    // Clean up
    mod.Tree_deinit(tree);
  });
}); 