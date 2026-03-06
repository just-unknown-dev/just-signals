## [1.0.1] - 2026-03-07

Fixed the git repository URL in `pubspec.yaml` to point to the correct GitHub repository for `just_signals`.

---

## [1.0.0] - 2026-03-07

Initial stable release of **just_signals** — a high-performance, signal-driven
state management package built for Flutter and `just_game_engine`.

### Core Signals (`lib/src/core/`)

- **`Signal<T>`** — mutable reactive primitive; notifies listeners only when
  the value actually changes. Supports `update()`, `forceNotify()`, and
  `debugLabel` for DevTools visibility.
- **`Computed<T>`** — lazily evaluated derived value that automatically tracks
  its own dependencies and caches the result until invalidated. Detects and
  throws on circular dependencies.
- **`Effect`** — side-effect callback that auto-tracks signal access, re-runs
  on dependency changes, and supports optional cleanup functions. Can be
  paused, resumed, and manually triggered.
- **`batch()` / `SignalBatch.run()`** — defers all listener notifications until
  the batch completes, collapsing multiple signal writes into a single
  rebuild pass.
- **`transaction()`** — like `batch()` but rolls back all signal values to
  their pre-transaction state if an exception is thrown.
- **`Selector<T, R>`** — derives a sub-value from a signal; only notifies
  when the selected portion changes. Extension `.select()` and `.selectMany()`
  available on all `Signal<T>` instances.
- **`combine2()` / `combine3()` / `combine4()`** — combines multiple signals
  into a single `Computed<R>` value.
- **`SignalScope`** — lifecycle container that automatically disposes all
  registered `Effect` instances when the scope is disposed.

### Flutter Widgets (`lib/src/widgets/`)

- **`SignalBuilder<T>`** — rebuilds only when a single `Signal<T>` or
  `Computed<T>` changes. Accepts an optional static `child` to avoid
  rebuilding unchanged sub-trees.
- **`SignalConsumer`** — rebuilds when any signal in a provided list changes.
  Ideal for widgets that depend on 2–5 related signals.
- **`SignalSelector<T, R>`** — subscribes to a derived slice of a signal;
  granular rebuilds without a full `Computed` declaration.
- **`SignalScopeWidget`** — `InheritedWidget` wrapper that exposes a
  `SignalScope` to the subtree, enabling automatic effect disposal tied to
  the widget lifecycle.
- **`SignalListenableBuilder`** — bridge for any `ValueListenable<T>` source,
  enabling `Signal` to integrate with existing Flutter APIs.

### Async Support (`lib/src/async/`)

- **`AsyncSignal<T>`** — wraps an async operation and exposes `idle`,
  `loading`, `data`, `error`, and `refreshing` states as a single
  `Signal<AsyncSnapshot<T>>`. Supports cancellation and refresh.
- **`StreamSignal<T>`** — wraps a `Stream<T>` with proper lifecycle
  management; auto-subscribes and disposes with the signal.
- **`FutureSignal<T>`** — wraps a `Future<T>` as a one-shot async signal,
  exposing the same loading/error/data pattern.

### Memory Layer — Zero-GC (`lib/src/memory/`)

- **`ObjectPool<T>`** — pre-allocates a pool of objects and recycles them via
  `acquire()` / `release()`, eliminating GC pressure in hot game-loop paths.
  Supports `initialSize`, `maxSize`, per-acquire and per-release callbacks,
  `prewarm()`, `shrink()`, and `releaseAll()`.
- **`RoundRobinPool<T>`** — fixed-size rotating pool; `next()` always returns
  the oldest object in the rotation, ideal for audio players and particle slots.
- **`MemoryArena`** — pre-allocated typed `Float32List` arena for entity
  position, velocity, and scale data. In-place `applyVelocity()` operation
  with no heap allocation per tick.
- **`TypedBuffer<T>`** — growable typed buffer with amortised resizing,
  optimised for particle and vertex data accumulation.
- **`PoolManager`** — centralised registry for multiple named `ObjectPool`
  instances; `register<T>()`, `acquire<T>()`, and `release<T>()` by key.

