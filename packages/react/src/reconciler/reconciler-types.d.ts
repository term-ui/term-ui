/**
 * TypeScript definitions for react-reconciler
 *
 * These type definitions are for the host config used by react-reconciler.
 * The type definitions are based on the documentation in packages/react-reconciler/README.md
 * and by examining the actual code usage in various renderer implementations.
 *
 * This focuses on the mutation mode implementation, which is the most common usage.
 */
declare module "react-reconciler" {
  import type { EventPriority } from "react-reconciler/constants";
  export const LegacyRoot = 0;
  export const ConcurrentRoot = 1;

  /**
   * Union type of all root tags
   */
  export type RootTag =
    | typeof LegacyRoot
    | typeof ConcurrentRoot;

  /**
   * Root tag values map for easy access to the numeric constants
   */

  export type OpaqueHandle = object;

  /**
   * Opaque root handle. Internal data structure used by React.
   * Represents the root of a React component tree.
   */
  export type OpaqueRoot = object;

  /**
   * Lane represents a level of priority for updates.
   * Part of React's priority-based scheduling system.
   */
  export type Lane = number;

  /**
   * A collection of Lanes.
   * Used to represent multiple priority levels.
   */
  export type Lanes = number;

  // Type for selector-related operations
  export type Selector = {
    type: string;
    value: unknown;
  };

  /**
   * Generic type for the react-reconciler host config.
   *
   * @template Type - The type of elements in the host environment (e.g., string for DOM elements like 'div', 'span')
   * @template Props - The type of props for host elements (e.g., DOM element attributes)
   * @template Container - The type of the root container (e.g., DOM element that hosts the React tree)
   * @template Instance - The type of host instances created during rendering (e.g., DOM nodes)
   * @template TextInstance - The type of text instances (e.g., DOM text nodes)
   * @template HydratableInstance - The type of hydratable instances for SSR
   * @template PublicInstance - The type exposed to refs (what users get when using refs)
   * @template HostContext - Context passed from parent to child during tree construction
   * @template UpdatePayload - Information about what needs to be updated on a node
   * @template ChildSet - Used only in persistence mode to represent a set of children
   * @template TimeoutHandle - Type of timeout handle returned by setTimeout equivalent
   * @template NoTimeout - Type representing no timeout value
   * @template SuspenseInstance - Type for suspense instances used in hydration
   */
  export interface HostConfig<
    Type,
    Props,
    Container,
    Instance,
    TextInstance,
    HydratableInstance = unknown,
    PublicInstance =
      | Instance
      | TextInstance
      | SuspenseInstance,
    HostContext = unknown,
    UpdatePayload = unknown,
    ChildSet = unknown,
    TimeoutHandle = unknown,
    NoTimeout = unknown,
    SuspenseInstance = never,
  > {
    //
    // ⭐️ Core Methods (Required)
    //

    /**
     * Creates a new host instance.
     *
     * This method should return a newly created node. For example, the DOM renderer
     * would call `document.createElement(type)` here and then set the properties from `props`.
     *
     * You can use `rootContainerInstance` to access the root container associated with
     * that tree. For example, in the DOM renderer, this is useful to get the correct
     * `document` reference that the root belongs to.
     *
     * The `hostContext` parameter lets you keep track of some information about your
     * current place in the tree. To learn more about it, see `getChildHostContext`.
     *
     * The `internalHandle` data structure is meant to be opaque. If you bend the rules
     * and rely on its internal fields, be aware that it may change significantly between versions.
     *
     * LIFECYCLE: This method happens **in the render phase**. It can (and usually should)
     * mutate the node it has just created before returning it, but it must not modify any
     * other nodes. It must not register any event handlers on the parent tree. This is because
     * an instance being created doesn't guarantee it would be placed in the tree — it could
     * be left unused and later collected by GC. If you need to do something when an instance
     * is definitely in the tree, look at `commitMount` instead.
     *
     * @param type - The type of element to create (e.g. 'div' for DOM)
     * @param props - The props for the element
     * @param rootContainerInstance - The root container
     * @param hostContext - The current host context
     * @param internalHandle - Internal React fiber instance (should not be modified directly)
     * @returns A newly created host instance
     */
    createInstance(
      type: Type,
      props: Props,
      rootContainerInstance: Container,
      hostContext: HostContext,
      internalHandle: OpaqueHandle,
    ): Instance;

    /**
     * Creates a text instance.
     *
     * Same as `createInstance`, but for text nodes. If your renderer doesn't support
     * text nodes, you can throw here.
     *
     * LIFECYCLE: This method happens **in the render phase**. It can mutate the created
     * text instance but must not modify any other nodes or register event handlers.
     *
     * @param text - The text content
     * @param rootContainerInstance - The root container
     * @param hostContext - The current host context
     * @param internalHandle - Internal React fiber instance
     * @returns A newly created text instance
     */
    createTextInstance(
      text: string,
      rootContainerInstance: Container,
      hostContext: HostContext,
      internalHandle: OpaqueHandle,
    ): TextInstance;

    /**
     * Adds a child instance during initial render phase.
     *
     * This method should mutate the `parentInstance` and add the child to its list of
     * children. For example, in the DOM this would translate to a `parentInstance.appendChild(child)` call.
     *
     * LIFECYCLE: This method happens **in the render phase**. It can mutate `parentInstance`
     * and `child`, but it must not modify any other nodes. It's called while the tree is
     * still being built up and not connected to the actual tree on the screen.
     *
     * @param parentInstance - The parent instance
     * @param child - The child instance to append
     */
    appendInitialChild(
      parentInstance: Instance,
      child: Instance | TextInstance,
    ): void;

    /**
     * Performs final operations on an instance during initial render.
     *
     * In this method, you can perform some final mutations on the `instance`. Unlike with
     * `createInstance`, by the time `finalizeInitialChildren` is called, all the initial
     * children have already been added to the `instance`, but the instance itself has not
     * yet been connected to the tree on the screen.
     *
     * There is a second purpose to this method. It lets you specify whether there is some
     * work that needs to happen when the node is connected to the tree on the screen. If
     * you return `true`, the instance will receive a `commitMount` call later. See the
     * documentation for `commitMount` for more details.
     *
     * LIFECYCLE: This method happens **in the render phase**. It can mutate `instance`,
     * but it must not modify any other nodes. It's called while the tree is still being
     * built up and not connected to the actual tree on the screen.
     *
     * @param instance - The instance to finalize
     * @param type - The type of the instance
     * @param props - The props of the instance
     * @param rootContainerInstance - The root container
     * @param hostContext - The current host context
     * @returns Whether commitMount should be called later for this instance
     */
    finalizeInitialChildren(
      instance: Instance,
      type: Type,
      props: Props,
      rootContainerInstance: Container,
      hostContext: HostContext,
    ): boolean;

    /**
     * Determines if the child content should be set as direct text content.
     *
     * Some target platforms support setting an instance's text content without manually
     * creating a text node. For example, in the DOM, you can set `node.textContent` instead
     * of creating a text node and appending it.
     *
     * If you return `true` from this method, React will assume that this node's children
     * are text, and will not create nodes for them. It will instead rely on you to have
     * filled that text during `createInstance`. This is a performance optimization. For
     * example, the DOM renderer returns `true` only if `type` is a known text-only parent
     * (like `'textarea'`) or if `props.children` has a `'string'` type. If you return `true`,
     * you will need to implement `resetTextContent` too.
     *
     * LIFECYCLE: This method happens **in the render phase**. Do not mutate the tree from it.
     *
     * @param type - The type of the instance
     * @param props - The props of the instance
     * @returns Whether the children should be set as text content
     */
    shouldSetTextContent(
      type: Type,
      props: Props,
    ): boolean;

    /**
     * Gets the initial host context from the root container.
     *
     * This method lets you return the initial host context from the root of the tree.
     * See `getChildHostContext` for the explanation of host context.
     *
     * LIFECYCLE: This method happens **in the render phase**. Do not mutate the tree from it.
     *
     * @param rootContainerInstance - The root container
     */
    getRootHostContext(
      rootContainerInstance: Container,
    ): HostContext;

    /**
     * Gets the host context for the child based on the parent context.
     *
     * Host context lets you track some information about where you are in the tree so that
     * it's available inside `createInstance` as the `hostContext` parameter. For example,
     * the DOM renderer uses it to track whether it's inside an HTML or an SVG tree, because
     * `createInstance` implementation needs to be different for them.
     *
     * If the node of this `type` does not influence the context you want to pass down,
     * you can return `parentHostContext`. Alternatively, you can return any custom object
     * representing the information you want to pass down.
     *
     * LIFECYCLE: This method happens **in the render phase**. Do not mutate the tree from it.
     *
     * @param parentHostContext - The parent host context
     * @param type - The type of the child instance
     * @param rootContainerInstance - The root container
     * @returns The child host context or the parent context if no changes
     */
    getChildHostContext(
      parentHostContext: HostContext,
      type: Type,
      rootContainerInstance: Container,
    ): HostContext;

    /**
     * Gets the public instance from a host instance.
     *
     * Determines what object gets exposed as a ref. You'll likely want to return
     * the `instance` itself. But in some cases it might make sense to only expose
     * some part of it.
     *
     * LIFECYCLE: This method is used when refs are created or updated, typically during
     * the commit phase.
     *
     * @param instance - The host instance
     * @returns The public instance
     */
    getPublicInstance(
      instance: Instance | TextInstance,
    ): PublicInstance;

    /**
     * Prepares for a commit. May store information needed during commit.
     *
     * This method lets you store some information before React starts making changes
     * to the tree on the screen. For example, the DOM renderer stores the current text
     * selection so that it can later restore it. This method is mirrored by `resetAfterCommit`.
     *
     * LIFECYCLE: This method is called right before React starts making changes to the host tree.
     *
     * @param containerInfo - The container
     * @returns Any value to be used in resetAfterCommit, or null
     */
    prepareForCommit(
      containerInfo: Container,
    ): null | object;

    /**
     * Resets after a commit has been completed.
     *
     * This method is called right after React has performed the tree mutations.
     * You can use it to restore something you've stored in `prepareForCommit` —
     * for example, text selection.
     *
     * LIFECYCLE: This method is called right after React has completed making changes to the host tree.
     *
     * @param containerInfo - The container
     */
    resetAfterCommit(
      containerInfo: Container,
    ): void;

    /**
     * Prepares a portal mount. Called when a portal is created.
     *
     * This method is called for a container that's used as a portal target.
     * Usually you can leave it empty.
     *
     * LIFECYCLE: This method is called when a portal container is first used.
     *
     * @param containerInfo - The container for the portal
     */
    preparePortalMount?(
      containerInfo: Container,
    ): void;

    //
    // ⭐️ Scheduling Methods (Required)
    //

    /**
     * Schedules a timeout.
     *
     * You can proxy this to `setTimeout` or its equivalent in your environment.
     *
     * LIFECYCLE: This method is used by React's internal scheduling system to set timers.
     *
     * @param fn - The function to call
     * @param delay - The delay in milliseconds
     * @returns A timeout handle
     */
    scheduleTimeout(
      fn: (...args: unknown[]) => unknown,
      delay?: number,
    ): TimeoutHandle;

    /**
     * Cancels a scheduled timeout.
     *
     * You can proxy this to `clearTimeout` or its equivalent in your environment.
     *
     * LIFECYCLE: This method is used to cancel previously scheduled timeouts.
     *
     * @param handle - The timeout handle to cancel
     */
    cancelTimeout(handle: TimeoutHandle): void;

    /**
     * A value that can never be a valid timeout ID.
     *
     * This is a property (not a function) that should be set to something
     * that can never be a valid timeout ID. For example, you can set it to `-1`.
     */
    noTimeout: NoTimeout;

    /**
     * Whether microtasks are supported in this environment.
     *
     * Set this to true to indicate that your renderer supports `scheduleMicrotask`.
     * We use microtasks as part of our discrete event implementation in React DOM.
     * If you're not sure if your renderer should support this, you probably should.
     * The option to not implement `scheduleMicrotask` exists so that platforms with
     * more control over user events, like React Native, can choose to use a different mechanism.
     */
    supportsMicrotasks?: boolean;

    /**
     * Schedules a microtask.
     *
     * You can proxy this to `queueMicrotask` or its equivalent in your environment.
     * Microtasks are executed before the next frame, unlike setTimeout which waits
     * for the next frame.
     *
     * LIFECYCLE: Used for high-priority work that should be executed before the next paint.
     *
     * @param fn - The function to call in the microtask
     */
    scheduleMicrotask?(fn: () => void): void;

    /**
     * Whether this is the primary renderer on the page.
     *
     * This is a property (not a function) that should be set to `true` if your
     * renderer is the main one on the page. For example, if you're writing a renderer
     * for the Terminal, it makes sense to set it to `true`, but if your renderer is
     * used *on top of* React DOM or some other existing renderer, set it to `false`.
     */
    isPrimaryRenderer: boolean;

    /**
     * Gets the current event priority based on the active event.
     *
     * The constant you return depends on which event, if any, is being handled right now:
     *
     * - **Discrete events:** If the active event is directly caused by the user (such as
     *   mouse and keyboard events) and each event in a sequence is intentional (e.g. `click`),
     *   return `DiscreteEventPriority`. This tells React that they should interrupt any
     *   background work and cannot be batched across time.
     *
     * - **Continuous events:** If the active event is directly caused by the user but the
     *   user can't distinguish between individual events in a sequence (e.g. `mouseover`),
     *   return `ContinuousEventPriority`. This tells React they should interrupt any
     *   background work but can be batched across time.
     *
     * - **Other events / No active event:** In all other cases, return `DefaultEventPriority`.
     *   This tells React that this event is considered background work, and interactive
     *   events will be prioritized over it.
     *
     * LIFECYCLE: This method is called during event handling to determine the priority of updates.
     *
     * @returns The current event priority
     */

    getCurrentUpdatePriority(): EventPriority;
    setCurrentUpdatePriority(
      newPriority: EventPriority,
    ): void;
    resolveUpdatePriority(): EventPriority;

    /**
     * Whether the renderer is operating in mutation mode.
     *
     * If your target platform is similar to the DOM and has methods similar to `appendChild`,
     * `removeChild`, and so on, you'll want to use the **mutation mode** by setting this to `true`.
     * This is the same mode used by React DOM, React ART, and the classic React Native renderer.
     *
     * In mutation mode, React will call methods like appendChild, removeChild to directly modify
     * existing nodes.
     *
     * You must specify either supportsMutation or supportsPersistence.
     */
    supportsMutation: boolean;

    /**
     * Whether the renderer is operating in persistence mode.
     *
     * If your target platform has immutable trees, you'll want the **persistence mode**
     * by setting this to `true`. In that mode, existing nodes are never mutated, and instead
     * every change clones the parent tree and then replaces the whole parent tree at the root.
     * This is the mode used by the React Native Fabric renderer.
     *
     * You must specify either supportsMutation or supportsPersistence.
     */
    supportsPersistence: boolean;

    /**
     * Whether the renderer supports hydration of server rendered content.
     *
     * Set this to true to support hydration - the process of "attaching" to the existing
     * tree during the initial render instead of creating it from scratch. For example,
     * the DOM renderer uses this to attach to an HTML markup.
     *
     * If this is true, you must implement all the hydration-related methods.
     */
    supportsHydration?: boolean;

    /**
     * Whether the environment allows to suspend the commit process.
     *
     * This method is called during render to determine if the Host Component type
     * and props require some kind of loading process to complete before committing an update.
     *
     * LIFECYCLE: Called during the render phase for each Host Component, before committing.
     * If this returns true, you must also implement preloadInstance, startSuspendingCommit,
     * suspendInstance, and waitForCommitToBeReady.
     *
     * @param type - The type of component
     * @param props - The props of the component
     * @returns Whether the commit might need to be suspended
     */
    maySuspendCommit?(
      type: Type,
      props: Props,
    ): boolean;

    /**
     * Whether updates can suspend the commit process.
     *
     * LIFECYCLE: Called during an update to determine if this update might need to
     * suspend the commit process.
     *
     * @returns Whether updates should be allowed to suspend the commit
     */
    maySuspendCommitOnUpdate?(): boolean;

    /**
     * Whether synchronous rendering can suspend the commit process.
     *
     * Determines if synchronous rendering can cause the commit to be suspended.
     * Typically false for browser environments to avoid unexpected UI freezes.
     *
     * LIFECYCLE: Called during synchronous rendering to check if the commit can be suspended.
     *
     * @returns Whether synchronous rendering can cause the commit to be suspended
     */
    maySuspendCommitInSyncRender?(): boolean;

    /**
     * Preloads an instance if it may suspend the commit.
     *
     * This method may be called during render if the Host Component type and props
     * might suspend a commit. It can be used to initiate any work that might shorten
     * the duration of a suspended commit.
     *
     * LIFECYCLE: Called during the render phase if maySuspendCommit returns true.
     *
     * @param type - The type of component
     * @param props - The props of the component
     */
    preloadInstance?(
      type: Type,
      props: Props,
    ): void;

    /**
     * Starts the suspending commit process.
     *
     * This method is called just before the commit phase. Use it to set up any necessary
     * state while any Host Components that might suspend this commit are evaluated to
     * determine if the commit must be suspended.
     *
     * LIFECYCLE: Called at the beginning of the commit phase if any component might suspend.
     */
    startSuspendingCommit?(): void;

    /**
     * Suspends an instance during commit.
     *
     * This method is called after `startSuspendingCommit` for each Host Component
     * that indicated it might suspend a commit. It should prepare the instance for
     * a potential suspended state.
     *
     * LIFECYCLE: Called during commit for each instance that might suspend, after
     * startSuspendingCommit is called.
     *
     * @param type - The type of component
     * @param props - The props of the component
     */
    suspendInstance?(
      type: Type,
      props: Props,
    ): void;

    /**
     * Determines if the commit should be suspended or can proceed immediately.
     *
     * This method is called after all `suspendInstance` calls are complete.
     *
     * LIFECYCLE: Called after all suspendInstance calls, but before actually committing changes.
     *
     * @returns null if the commit can happen immediately, or a function to initiate the
     * commit when ready which itself returns a cancellation function
     */
    waitForCommitToBeReady():
      | null
      | ((initiate: () => void) => () => void);

    /**
     * For getting instance from a node (optional).
     *
     * This method allows you to get the React instance associated with a DOM node or
     * other platform-specific node. Used by React DevTools and event system.
     *
     * @param node - The platform node
     * @returns The React fiber or instance, or null
     */
    getInstanceFromNode?(
      node: unknown,
    ): unknown | null;

    /**
     * Called before active instance blurs (optional).
     *
     * This method is called before the active instance loses focus. Can be used to
     * save state or perform cleanup.
     *
     * LIFECYCLE: Called before blur event processing.
     */
    beforeActiveInstanceBlur?(): void;

    /**
     * Called after active instance blurs (optional).
     *
     * This method is called after the active instance has lost focus. Can be used to
     * update state or perform side effects after blur.
     *
     * LIFECYCLE: Called after blur event processing.
     */
    afterActiveInstanceBlur?(): void;

    /**
     * For preparing scope updates (optional).
     *
     * Used for React scopes feature to prepare updates to a scope instance.
     *
     * @param scopeInstance - The scope instance
     * @param instance - The component instance
     */
    prepareScopeUpdate?(
      scopeInstance: unknown,
      instance: Instance,
    ): void;

    /**
     * For getting instance from scope (optional).
     *
     * Used for React scopes feature to get the component instance from a scope.
     *
     * @param scopeInstance - The scope instance
     * @returns The component instance or null
     */
    getInstanceFromScope?(
      scopeInstance: unknown,
    ): Instance | null;

    /**
     * Detach a deleted instance for garbage collection purposes (optional).
     *
     * This method is called when an instance is removed from the tree. It allows
     * the renderer to perform any necessary cleanup for garbage collection.
     *
     * LIFECYCLE: Called during the commit phase when an instance is removed.
     *
     * @param instance - The instance being removed
     */
    detachDeletedInstance?(
      instance: Instance,
    ): void;

    //
    // ⭐️ Mutation Methods (Required when supportsMutation is true)
    //

    /**
     * Appends a child to a parent instance.
     *
     * This method should mutate the `parentInstance` and add the child to its list of
     * children. For example, in the DOM this would translate to a `parentInstance.appendChild(child)` call.
     *
     * LIFECYCLE: Although this method runs in the commit phase, you still should not
     * mutate any other nodes in it. If you need to do some additional work when a node
     * is definitely connected to the visible tree, look at `commitMount`.
     *
     * @param parentInstance - The parent instance
     * @param child - The child instance to append
     */
    appendChild?(
      parentInstance: Instance,
      child: Instance | TextInstance,
    ): void;

    /**
     * Appends a child to a container.
     *
     * Same as `appendChild`, but for when a node is attached to the root container.
     * This is useful if attaching to the root has a slightly different implementation,
     * or if the root container nodes are of a different type than the rest of the tree.
     *
     * LIFECYCLE: Called during the commit phase to attach nodes to the root container.
     *
     * @param container - The container
     * @param child - The child instance to append
     */
    appendChildToContainer?(
      container: Container,
      child: Instance | TextInstance,
    ): void;

    /**
     * Inserts a child before another child within a parent.
     *
     * This method should mutate the `parentInstance` and place the `child` before
     * `beforeChild` in the list of its children. For example, in the DOM this would
     * translate to a `parentInstance.insertBefore(child, beforeChild)` call.
     *
     * Note that React uses this method both for insertions and for reordering nodes.
     * Similar to DOM, it is expected that you can call `insertBefore` to reposition
     * an existing child. Do not mutate any other parts of the tree from it.
     *
     * LIFECYCLE: Called during the commit phase when the position of nodes changes.
     *
     * @param parentInstance - The parent instance
     * @param child - The child to insert
     * @param beforeChild - The reference child (to insert before)
     */
    insertBefore?(
      parentInstance: Instance,
      child: Instance | TextInstance,
      beforeChild: NoInfer<
        Instance | TextInstance | SuspenseInstance
      >,
    ): void;

    /**
     * Inserts a child before another child in a container.
     *
     * Same as `insertBefore`, but for when a node is attached to the root container.
     * This is useful if attaching to the root has a slightly different implementation,
     * or if the root container nodes are of a different type than the rest of the tree.
     *
     * LIFECYCLE: Called during the commit phase when the position of nodes changes in the root container.
     *
     * @param container - The container
     * @param child - The child to insert
     * @param beforeChild - The reference child (to insert before)
     */
    insertInContainerBefore?(
      container: Container,
      child: Instance | TextInstance,
      beforeChild:
        | Instance
        | TextInstance
        | SuspenseInstance,
    ): void;

    /**
     * Removes a child from a parent.
     *
     * This method should mutate the `parentInstance` to remove the `child` from the list of its children.
     *
     * React will only call it for the top-level node that is being removed. It is expected
     * that garbage collection would take care of the whole subtree. You are not expected
     * to traverse the child tree in it.
     *
     * LIFECYCLE: Called during the commit phase when nodes are removed from the tree.
     *
     * @param parentInstance - The parent instance
     * @param child - The child to remove
     */
    removeChild?(
      parentInstance: Instance,
      child: NoInfer<
        Instance | TextInstance | SuspenseInstance
      >,
    ): void;

    /**
     * Removes a child from a container.
     *
     * Same as `removeChild`, but for when a node is detached from the root container.
     * This is useful if attaching to the root has a slightly different implementation,
     * or if the root container nodes are of a different type than the rest of the tree.
     *
     * LIFECYCLE: Called during the commit phase when nodes are removed from the root container.
     *
     * @param container - The container
     * @param child - The child to remove
     */
    removeChildFromContainer?(
      container: Container,
      child: NoInfer<
        Instance | TextInstance | SuspenseInstance
      >,
    ): void;

    /**
     * Clears the content of a container.
     *
     * This method should mutate the `container` root node and remove all children from it.
     *
     * LIFECYCLE: Called when a container needs to be cleared, such as when unmounting the root.
     *
     * @param container - The container to clear
     */
    clearContainer?(container: Container): void;

    /**
     * Resets the text content of an instance.
     *
     * If you returned `true` from `shouldSetTextContent` for the previous props,
     * but returned `false` from `shouldSetTextContent` for the next props, React will
     * call this method so that you can clear the text content you were managing manually.
     * For example, in the DOM you could set `node.textContent = ''`.
     *
     * LIFECYCLE: Called during the commit phase when text content needs to be cleared.
     * Only needed if shouldSetTextContent can return true.
     *
     * @param instance - The instance to reset text content for
     */
    resetTextContent?(instance: Instance): void;

    /**
     * Updates the text content of a text instance.
     *
     * This method should mutate the `textInstance` and update its text content to `nextText`.
     *
     * Here, `textInstance` is a node created by `createTextInstance`.
     *
     * LIFECYCLE: Called during the commit phase when text content changes.
     *
     * @param textInstance - The text instance to update
     * @param oldText - The previous text
     * @param newText - The new text
     */
    commitTextUpdate?(
      textInstance: TextInstance,
      oldText: string,
      newText: string,
    ): void;

    /**
     * Called when an instance with commitMount requested is mounted.
     *
     * This method is only called if you returned `true` from `finalizeInitialChildren` for this instance.
     *
     * It lets you do some additional work after the node is actually attached to the tree
     * on the screen for the first time. For example, the DOM renderer uses it to trigger
     * focus on nodes with the `autoFocus` attribute.
     *
     * Note that `commitMount` does not mirror `removeChild` one to one because `removeChild`
     * is only called for the top-level removed node. This is why ideally `commitMount` should
     * not mutate any nodes other than the `instance` itself. For example, if it registers some
     * events on some node above, it will be your responsibility to traverse the tree in `removeChild`
     * and clean them up, which is not ideal.
     *
     * LIFECYCLE: Called during the commit phase after the instance has been added to the tree,
     * but only if finalizeInitialChildren returned true for this instance.
     *
     * @param instance - The instance that was mounted
     * @param type - The type of the instance
     * @param props - The props of the instance
     * @param internalHandle - Internal React fiber instance
     */
    commitMount?(
      instance: Instance,
      type: Type,
      props: Props,
      internalHandle: OpaqueHandle,
    ): void;

    /**
     * Updates an instance with new props.
     *
     * This method should mutate the `instance` to match `nextProps`.
     *
     * The `internalHandle` data structure is meant to be opaque. If you bend the rules
     * and rely on its internal fields, be aware that it may change significantly between versions.
     *
     * LIFECYCLE: Called during the commit phase when an instance needs to be updated.
     *
     * @param instance - The instance to update
     * @param type - The type of the instance
     * @param oldProps - The old props
     * @param newProps - The new props
     * @param internalHandle - Internal React fiber instance
     */
    commitUpdate?(
      instance: Instance,
      type: Type,
      oldProps: Props,
      newProps: Props,
      internalInstanceHandle: unknown,
    ): void;

    /**
     * Hides an instance (used by Suspense).
     *
     * This method should make the `instance` invisible without removing it from the tree.
     * For example, it can apply visual styling to hide it. It is used by Suspense to hide
     * the tree while the fallback is visible.
     *
     * LIFECYCLE: Called when Suspense needs to hide content while showing a fallback.
     *
     * @param instance - The instance to hide
     */
    hideInstance?(instance: Instance): void;

    /**
     * Hides a text instance (used by Suspense).
     *
     * Same as `hideInstance`, but for nodes created by `createTextInstance`.
     *
     * LIFECYCLE: Called when Suspense needs to hide text content while showing a fallback.
     *
     * @param textInstance - The text instance to hide
     */
    hideTextInstance?(
      textInstance: TextInstance,
    ): void;

    /**
     * Unhides an instance.
     *
     * This method should make the `instance` visible, undoing what `hideInstance` did.
     *
     * LIFECYCLE: Called when Suspense resolves and needs to reveal previously hidden content.
     *
     * @param instance - The instance to unhide
     * @param props - The props to use
     */
    unhideInstance?(
      instance: Instance,
      props: Props,
    ): void;

    /**
     * Unhides a text instance.
     *
     * Same as `unhideInstance`, but for nodes created by `createTextInstance`.
     *
     * LIFECYCLE: Called when Suspense resolves and needs to reveal previously hidden text content.
     *
     * @param textInstance - The text instance to unhide
     * @param text - The text to display
     */
    unhideTextInstance?(
      textInstance: TextInstance,
      text: string,
    ): void;

    //
    // ⭐️ Persistence Methods (Required when supportsPersistence is true)
    //

    /**
     * Clones an instance.
     *
     * This method is used in persistence mode to clone an instance for updates
     * instead of mutating it directly. It should create a new instance with the
     * same properties as the original.
     *
     * LIFECYCLE: Called during the render phase in persistence mode when an instance
     * needs to be updated.
     *
     * @param instance - The instance to clone
     * @param updatePayload - Update information
     * @param type - The type of the instance
     * @param oldProps - The old props
     * @param newProps - The new props
     * @param internalInstanceHandle - Internal React fiber instance
     * @param keepChildren - Whether to keep or discard children
     * @param recyclableInstance - An instance that can be recycled (optimization)
     * @returns The new cloned instance
     */
    cloneInstance?(
      instance: Instance,
      updatePayload: null | UpdatePayload,
      type: Type,
      oldProps: Props,
      newProps: Props,
      internalInstanceHandle: OpaqueHandle,
      keepChildren: boolean,
      recyclableInstance: Instance | null,
    ): Instance;

    /**
     * Creates a container child set during updates.
     *
     * In persistence mode, this creates a new set to hold the children of a container
     * during an update, since we can't mutate the existing children.
     *
     * LIFECYCLE: Called during the render phase in persistence mode when preparing to update a container.
     *
     * @param container - The container
     * @returns A child set
     */
    createContainerChildSet?(
      container: Container,
    ): ChildSet;

    /**
     * Appends a child to a container child set.
     *
     * In persistence mode, this adds a child to the set that will replace the container's
     * children during the next commit.
     *
     * LIFECYCLE: Called during the render phase in persistence mode when building the new child set.
     *
     * @param childSet - The child set
     * @param child - The child to append
     */
    appendChildToContainerChildSet?(
      childSet: ChildSet,
      child: Instance | TextInstance,
    ): void;

    /**
     * Finalizes the children in a container.
     *
     * Called before replaceContainerChildren to give the renderer a chance to
     * prepare the new set of children for insertion.
     *
     * LIFECYCLE: Called during the commit phase in persistence mode before replacing container children.
     *
     * @param container - The container
     * @param newChildren - The new children
     */
    finalizeContainerChildren?(
      container: Container,
      newChildren: ChildSet,
    ): void;

    /**
     * Replaces container children.
     *
     * In persistence mode, this replaces all children of a container with a new set
     * instead of mutating the existing children.
     *
     * LIFECYCLE: Called during the commit phase in persistence mode to replace container children.
     *
     * @param container - The container
     * @param newChildren - The new children
     */
    replaceContainerChildren?(
      container: Container,
      newChildren: ChildSet,
    ): void;

    /**
     * Clones a hidden instance.
     *
     * In persistence mode, this creates a hidden clone of an instance for Suspense.
     *
     * LIFECYCLE: Called when preparing to hide an instance in persistence mode.
     *
     * @param instance - The instance to clone
     * @param type - The type of the instance
     * @param props - The props of the instance
     * @param internalInstanceHandle - Internal React fiber instance
     * @returns The cloned instance
     */
    cloneHiddenInstance?(
      instance: Instance,
      type: Type,
      props: Props,
      internalInstanceHandle: OpaqueHandle,
    ): Instance;

    /**
     * Clones a hidden text instance.
     *
     * In persistence mode, this creates a hidden clone of a text instance for Suspense.
     *
     * LIFECYCLE: Called when preparing to hide a text instance in persistence mode.
     *
     * @param instance - The text instance to clone
     * @param text - The text
     * @param internalInstanceHandle - Internal React fiber instance
     * @returns The cloned text instance
     */
    cloneHiddenTextInstance?(
      instance: TextInstance,
      text: string,
      internalInstanceHandle: OpaqueHandle,
    ): TextInstance;

    //
    // ⭐️ Hydration Methods (Required when supportsHydration is true)
    //

    /**
     * Determines if instance can be hydrated.
     *
     * Checks if an existing host instance (from server rendering) can be hydrated
     * for the given type and props.
     *
     * LIFECYCLE: Called during initial mount when trying to hydrate from server-rendered content.
     *
     * @param instance - The instance to check
     * @param type - The type of the instance
     * @param props - The props of the instance
     * @returns The hydrated instance or null if can't be hydrated
     */
    canHydrateInstance?(
      instance: HydratableInstance,
      type: Type,
      props: Props,
    ): Instance | null;

    /**
     * Determines if a text instance can be hydrated.
     *
     * Checks if an existing text node (from server rendering) can be hydrated.
     *
     * LIFECYCLE: Called during initial mount when trying to hydrate from server-rendered content.
     *
     * @param instance - The instance to check
     * @param text - The text
     * @returns The hydrated text instance or null if can't be hydrated
     */
    canHydrateTextInstance?(
      instance: HydratableInstance,
      text: string,
    ): TextInstance | null;

    /**
     * Determines if a suspense instance can be hydrated.
     *
     * Checks if an existing node can be hydrated as a suspense boundary.
     *
     * LIFECYCLE: Called during initial mount when trying to hydrate suspense boundaries.
     *
     * @param instance - The instance to check
     * @returns The hydrated suspense instance or null if can't be hydrated
     */
    canHydrateSuspenseInstance?(
      instance: HydratableInstance,
    ): SuspenseInstance | null;

    /**
     * Gets the next hydration sibling.
     *
     * During hydration, this finds the next sibling that can be hydrated.
     *
     * LIFECYCLE: Called during the hydration process to traverse the server-rendered tree.
     *
     * @param instance - The current instance
     * @returns The next sibling or null
     */
    getNextHydratableSibling?(
      instance: HydratableInstance | null,
    ): HydratableInstance | null;

    /**
     * Gets the first hydratable child.
     *
     * During hydration, this finds the first child that can be hydrated.
     *
     * LIFECYCLE: Called during the hydration process to traverse the server-rendered tree.
     *
     * @param parentInstance - The parent instance
     * @returns The first hydratable child or null
     */
    getFirstHydratableChild?(
      parentInstance: Instance | Container,
    ): HydratableInstance | null;

    /**
     * Gets the first hydratable child in a container.
     *
     * During hydration, this finds the first child in the container that can be hydrated.
     *
     * LIFECYCLE: Called during the hydration process for the root container.
     *
     * @param container - The container
     * @returns The first hydratable child or null
     */
    getFirstHydratableChildWithinContainer?(
      container: Container,
    ): HydratableInstance | null;

    /**
     * Gets the first hydratable child within a suspense instance.
     *
     * During hydration, this finds the first child in a suspense boundary that can be hydrated.
     *
     * LIFECYCLE: Called during the hydration process for suspense boundaries.
     *
     * @param suspenseInstance - The suspense instance
     * @returns The first hydratable child or null
     */
    getFirstHydratableChildWithinSuspenseInstance?(
      suspenseInstance: SuspenseInstance,
    ): HydratableInstance | null;

    /**
     * Hydrates an instance by matching it with the React tree.
     *
     * This reconciles a server-rendered node with the React component tree,
     * reusing the existing DOM or native view node.
     *
     * LIFECYCLE: Called during the initial mount to hydrate server-rendered content.
     *
     * @param instance - The instance to hydrate
     * @param type - The type of the instance
     * @param props - The props of the instance
     * @param rootContainerInstance - The root container
     * @param hostContext - The host context
     * @param internalInstanceHandle - Internal React fiber instance
     * @returns The update payload if successful or null
     */
    hydrateInstance?(
      instance: Instance,
      type: Type,
      props: Props,
      rootContainerInstance: Container,
      hostContext: HostContext,
      internalInstanceHandle: OpaqueHandle,
    ): UpdatePayload | null;

    /**
     * Hydrates a text instance.
     *
     * This reconciles a server-rendered text node with the React component tree,
     * reusing the existing text node.
     *
     * LIFECYCLE: Called during the initial mount to hydrate server-rendered text.
     *
     * @param textInstance - The text instance
     * @param text - The text
     * @param internalInstanceHandle - Internal React fiber instance
     * @returns Whether hydration was successful
     */
    hydrateTextInstance?(
      textInstance: TextInstance,
      text: string,
      internalInstanceHandle: OpaqueHandle,
    ): boolean;

    /**
     * Hydrates a suspense instance.
     *
     * This reconciles a server-rendered suspense boundary with the React component tree.
     *
     * LIFECYCLE: Called during the initial mount to hydrate suspense boundaries.
     *
     * @param suspenseInstance - The suspense instance
     * @param internalInstanceHandle - Internal React fiber instance
     */
    hydrateSuspenseInstance?(
      suspenseInstance: SuspenseInstance,
      internalInstanceHandle: OpaqueHandle,
    ): void;

    /**
     * Gets next hydratable instance after suspense instance.
     *
     * During hydration, this finds the next sibling after a suspense boundary.
     *
     * LIFECYCLE: Called during the hydration process when traversing past a suspense boundary.
     *
     * @param suspenseInstance - The suspense instance
     * @returns The next hydratable instance or null
     */
    getNextHydratableInstanceAfterSuspenseInstance?(
      suspenseInstance: SuspenseInstance,
    ): HydratableInstance | null;

    /**
     * Called when container has been hydrated.
     *
     * This is called after the container and its children have been hydrated.
     *
     * LIFECYCLE: Called after a container is successfully hydrated.
     *
     * @param container - The container
     */
    commitHydratedContainer?(
      container: Container,
    ): void;

    /**
     * Called when suspense instance has been hydrated.
     *
     * This is called after a suspense boundary and its children have been hydrated.
     *
     * LIFECYCLE: Called after a suspense boundary is successfully hydrated.
     *
     * @param suspenseInstance - The suspense instance
     */
    commitHydratedSuspenseInstance?(
      suspenseInstance: SuspenseInstance,
    ): void;

    /**
     * Clear the suspense boundary.
     *
     * This removes the suspense boundary placeholder when content is ready to show.
     *
     * LIFECYCLE: Called when suspense content is ready to be shown.
     *
     * @param suspenseInstance - The suspense instance
     */
    clearSuspenseBoundary?(
      suspenseInstance: SuspenseInstance,
    ): void;

    /**
     * Clear the suspense boundary from container.
     *
     * This removes the suspense boundary placeholder from a container.
     *
     * LIFECYCLE: Called when suspense content in a container is ready to be shown.
     *
     * @param container - The container
     * @param suspenseInstance - The suspense instance
     */
    clearSuspenseBoundaryFromContainer?(
      container: Container,
      suspenseInstance: SuspenseInstance,
    ): void;

    /**
     * Checks if suspense instance is in pending state.
     *
     * Determines if a suspense boundary is showing the fallback state.
     *
     * LIFECYCLE: Called during hydration to determine the state of a suspense boundary.
     *
     * @param instance - The suspense instance
     * @returns Whether the suspense instance is pending
     */
    isSuspenseInstancePending?(
      instance: SuspenseInstance,
    ): boolean;

    /**
     * Checks if suspense instance is in fallback state.
     *
     * Determines if a suspense boundary is showing the fallback content.
     *
     * LIFECYCLE: Called during hydration to determine the state of a suspense boundary.
     *
     * @param instance - The suspense instance
     * @returns Whether the suspense instance is in fallback state
     */
    isSuspenseInstanceFallback?(
      instance: SuspenseInstance,
    ): boolean;

    /**
     * Registers a retry callback for a suspense instance.
     *
     * This sets up a callback to retry showing content after a suspense boundary.
     *
     * LIFECYCLE: Called during hydration to set up retry mechanisms for suspended content.
     *
     * @param instance - The suspense instance
     * @param callback - The function to call to retry showing content
     */
    registerSuspenseInstanceRetry?(
      instance: SuspenseInstance,
      callback: () => void,
    ): void;
  }
  type SuspenseHydrationCallbacks<
    SuspenseInstance,
  > = {
    onHydrated?: (
      suspenseInstance: SuspenseInstance,
    ) => void;
    onDeleted?: (
      suspenseInstance: SuspenseInstance,
    ) => void;
  };
  /**
   * The public API of the React reconciler.
   */
  export interface Reconciler<
    Container,
    Instance,
    TextInstance,
    SuspenseInstance,
    PublicInstance,
  > {
    /**
     * Creates a root container for rendering React elements.
     */
    createContainer(
      containerInfo: Container,
      tag: RootTag,
      hydrationCallbacks: null | SuspenseHydrationCallbacks<SuspenseInstance>,
      isStrictMode: boolean,
      concurrentUpdatesByDefaultOverride:
        | boolean
        | null,
      identifierPrefix: string,
      onUncaughtError: (
        error: unknown,
        errorInfo: { componentStack?: string },
      ) => void,
      onCaughtError: (
        error: unknown,
        errorInfo: {
          componentStack?: string;
          errorBoundary?: React.Component<
            unknown,
            unknown
          >;
        },
      ) => void,
      onRecoverableError: (
        error: unknown,
        errorInfo: { componentStack?: string },
      ) => void,
      transitionCallbacks: object | null,
    ): OpaqueRoot;

    /**
     * Creates a hydration container for server-rendered content.
     */
    createHydrationContainer(
      initialChildren: React.ReactNode,
      callback: (() => void) | null | undefined,
      containerInfo: Container,
      tag: RootTag,
      hydrationCallbacks: null | SuspenseHydrationCallbacks<SuspenseInstance>,
      isStrictMode: boolean,
      concurrentUpdatesByDefaultOverride:
        | boolean
        | null,
      identifierPrefix: string,
      onUncaughtError: (
        error: unknown,
        errorInfo: { componentStack?: string },
      ) => void,
      onCaughtError: (
        error: unknown,
        errorInfo: {
          componentStack?: string;
          errorBoundary?: React.Component<
            unknown,
            unknown
          >;
        },
      ) => void,
      onRecoverableError: (
        error: unknown,
        errorInfo: { componentStack?: string },
      ) => void,
      transitionCallbacks: object | null,
      formState?: unknown,
    ): OpaqueRoot;

    /**
     * Updates a container with React elements.
     */
    updateContainer(
      element: React.ReactNode,
      container: OpaqueRoot,
      parentComponent:
        | React.Component<unknown, unknown>
        | null
        | undefined,
      callback?: (() => void) | null | undefined,
    ): Lane;

    /**
     * Updates a container synchronously with React elements.
     */
    updateContainerSync(
      element: React.ReactNode,
      container: OpaqueRoot,
      parentComponent:
        | React.Component<unknown, unknown>
        | null
        | undefined,
      callback?: (() => void) | null | undefined,
    ): Lane;

    /**
     * Creates a portal for rendering children into a different container.
     */
    createPortal(
      children: React.ReactNode,
      containerInfo: Container,
      implementation: unknown,
    ): React.ReactPortal;

    /**
     * Gets the public root instance from a container.
     */
    getPublicRootInstance(
      container: OpaqueRoot,
    ):
      | React.Component<unknown, unknown>
      | PublicInstance
      | null;

    /**
     * Finds a host instance for a component.
     */
    findHostInstance(
      component: object,
    ): PublicInstance | null;

    /**
     * Finds a host instance with a warning for a component.
     */
    findHostInstanceWithWarning(
      component: object,
      methodName: string,
    ): PublicInstance | null;

    /**
     * Finds a host instance with no portals for a component.
     */
    findHostInstanceWithNoPortals(
      fiber: object,
    ): PublicInstance | null;

    /**
     * Batches multiple updates to improve performance.
     */
    batchedUpdates<T>(
      fn: () => T,
      a?: unknown,
    ): T;

    /**
     * Performs updates at deferred priority.
     */
    deferredUpdates<T>(fn: () => T): T;

    /**
     * Performs discrete updates for events like user interactions.
     */
    discreteUpdates<T>(
      fn: () => T,
      a?: unknown,
      b?: unknown,
      c?: unknown,
      d?: unknown,
    ): T;

    /**
     * Flushes synchronous work.
     */
    flushSync<T>(fn: () => T): T;

    /**
     * Alias for flushSync to match new API name.
     */
    flushSyncFromReconciler<T>(fn: () => T): T;

    /**
     * Internal method to flush synchronous work.
     */
    flushSyncWork(): void;

    /**
     * Flushes passive effects.
     */
    flushPassiveEffects(): boolean;

    /**
     * Injects into React DevTools.
     */
    injectIntoDevTools(devToolsConfig: {
      findFiberByHostInstance: (
        instance: PublicInstance,
      ) => object;
      bundleType: number;
      version: string;
      rendererPackageName: string;
      rendererConfig?: object;
    }): boolean;

    /**
     * Attempts continuous hydration.
     */
    attemptContinuousHydration(
      fiber: object,
    ): void;

    /**
     * Attempts synchronous hydration.
     */
    attemptSynchronousHydration(
      fiber: object,
    ): void;

    /**
     * Attempts hydration at current priority.
     */
    attemptHydrationAtCurrentPriority(
      fiber: object,
    ): void;

    /**
     * Determines if a fiber should error.
     */
    shouldError(fiber: object): boolean;

    /**
     * Determines if a fiber should suspend.
     */
    shouldSuspend(fiber: object): boolean;

    /**
     * Creates a component selector for testing.
     */
    createComponentSelector(
      component: React.ComponentType<unknown>,
    ): Selector;

    /**
     * Creates a text selector for testing.
     */
    createTextSelector(text: string): Selector;

    /**
     * Creates a test name selector for testing.
     */
    createTestNameSelector(id: string): Selector;

    /**
     * Creates a role selector for testing.
     */
    createRoleSelector(role: string): Selector;

    /**
     * Creates a pseudo-class selector for testing.
     */
    createHasPseudoClassSelector(
      selectors: Selector[],
    ): Selector;

    /**
     * Finds all nodes matching selectors.
     */
    findAllNodes(
      hostRoot: object,
      selectors: Selector[],
    ): Array<PublicInstance>;

    /**
     * Gets failure description for findAllNodes.
     */
    getFindAllNodesFailureDescription(
      hostRoot: object,
      selectors: Selector[],
    ): string;

    /**
     * Finds bounding rects for selectors.
     */
    findBoundingRects(
      hostRoot: object,
      selectors: Selector[],
    ): Array<DOMRect | object>;

    /**
     * Focuses within elements matching selectors.
     */
    focusWithin(
      hostRoot: object,
      selectors: Selector[],
    ): boolean;

    /**
     * Observes visible rects for elements matching selectors.
     */
    observeVisibleRects(
      hostRoot: object,
      selectors: Selector[],
      callback: (
        rects: Array<DOMRect | object>,
      ) => void,
      options?: {
        threshold?: number;
        rootMargin?: string;
      },
    ): () => void;

    /**
     * Starts a host transition.
     */
    startHostTransition(
      formFiber: object,
      pendingState: object,
      action: (formData: FormData) => void,
      formData: FormData,
    ): void;

    /**
     * Default handler for uncaught errors.
     */
    defaultOnUncaughtError(error: Error): void;

    /**
     * Default handler for caught errors.
     */
    defaultOnCaughtError(error: Error): void;

    /**
     * Default handler for recoverable errors.
     */
    defaultOnRecoverableError(error: Error): void;

    /**
     * Checks if React is already rendering.
     */
    isAlreadyRendering(): boolean;
  }

  /**
   * React reconciler factory function. Creates a new React reconciler instance.
   */
  export default function ReactReconciler<
    Type,
    Props = Record<string, unknown> | undefined,
    Container,
    Instance,
    TextInstance,
    HydratableInstance,
    PublicInstance,
    HostContext,
    UpdatePayload,
    ChildSet,
    TimeoutHandle,
    NoTimeout,
    SuspenseInstance = never,
  >(
    config: HostConfig<
      Type,
      Props,
      Container,
      Instance,
      TextInstance,
      HydratableInstance,
      PublicInstance,
      HostContext,
      UpdatePayload,
      ChildSet,
      TimeoutHandle,
      NoTimeout,
      SuspenseInstance
    >,
  ): Reconciler<
    Container,
    Instance,
    TextInstance,
    SuspenseInstance,
    PublicInstance
  >;
}

declare module "react-reconciler/constants" {
  export const NoEventPriority = 0;
  export const DiscreteEventPriority = 2;
  export const ContinuousEventPriority = 8;
  export const DefaultEventPriority = 32;
  export const IdleEventPriority = 268435456;
  export type EventPriority =
    | typeof NoEventPriority
    | typeof DiscreteEventPriority
    | typeof ContinuousEventPriority
    | typeof DefaultEventPriority
    | typeof IdleEventPriority;
  export const LegacyRoot = 0;
  export const ConcurrentRoot = 1;
}
