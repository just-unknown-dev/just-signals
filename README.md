# Just Signals

A high-performance signal-driven state management package for **just_game_engine**. Designed for 60 FPS game loops with zero garbage collection pressure.

## Features

- **Core Signals**: Reactive primitives (`Signal`, `Computed`, `Effect`) with surgical precision updates
- **Memory Layer**: Zero-GC memory pooling with typed arrays (`MemoryArena`, `ObjectPool`)
- **ECS Integration**: Reactive wrappers for Entity-Component-System (`ComponentSignal`, `EntitySignal`, `WorldSignal`)
- **Flutter Widgets**: Efficient rebuilding with `SignalBuilder` and `SignalConsumer`
- **Async Support**: `AsyncSignal`, `StreamSignal`, and `FutureSignal` for async operations

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  just_signals:
    path: ../just_signals  # Or use git/pub reference
```

## Quick Start

### Basic Signal Usage

```dart
import 'package:just_signals/just_signals.dart';

// Create a signal
final count = Signal(0);

// Read value (registers dependency in computed/effect context)
print(count.value); // 0

// Update value (notifies listeners)
count.value++;

// Update with function
count.update((c) => c * 2);
```

### Computed Values

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

// Computed automatically tracks dependencies
final fullName = Computed(() => '${firstName.value} ${lastName.value}');

print(fullName.value); // 'John Doe'

firstName.value = 'Jane';
print(fullName.value); // 'Jane Doe' (automatically recomputed)
```

### Effects (Side Effects)

```dart
final count = Signal(0);

// Effect runs when dependencies change
final effect = Effect(() {
  print('Count changed to: ${count.value}');
  return () => print('Cleanup'); // Optional cleanup
});

count.value = 1; // Prints: "Cleanup" then "Count changed to: 1"

effect.dispose(); // Prints: "Cleanup"
```

### Batching Updates

```dart
final x = Signal(0);
final y = Signal(0);

// Batch multiple updates - single notification at the end
batch(() {
  x.value = 10;
  y.value = 20;
});
```

## Flutter Widgets

### SignalBuilder

Rebuilds only when the signal changes:

```dart
SignalBuilder<int>(
  signal: count,
  builder: (context, value, child) => Text('Count: $value'),
);
```

### SignalConsumer (Multiple Signals)

```dart
SignalConsumer(
  signals: [firstName, lastName],
  builder: (context, child) => Text('${firstName.value} ${lastName.value}'),
);
```

### SignalSelector (Partial Rebuilds)

Only rebuilds when the selected portion changes:

```dart
SignalSelector<User, String>(
  signal: userSignal,
  selector: (user) => user.name,
  builder: (context, name, child) => Text(name),
);
```

## Memory Layer (Zero-GC)

### MemoryArena

Pre-allocated typed arrays for entity data:

```dart
// Pre-allocate space for 1000 entities
final arena = MemoryArena(capacity: 1000);

// Allocate a slot
final slot = arena.allocate();

// Modify in place - no allocations!
arena.setPosition(slot, 100.0, 200.0);
arena.setVelocity(slot, 50.0, -30.0);

// Apply physics
arena.applyVelocity(slot, deltaTime);

// Free when done
arena.free(slot);
```

### ObjectPool

Reuse objects to avoid GC:

```dart
final bulletPool = ObjectPool<Bullet>(
  create: () => Bullet(),
  reset: (b) => b.reset(),
  initialSize: 100, // Pre-warm
);

// Acquire from pool
final bullet = bulletPool.acquire();

// Use bullet...

// Return to pool
bulletPool.release(bullet);
```

## ECS Integration

### ComponentSignal

Reactive access to component properties:

```dart
final transform = entity.getComponent<TransformComponent>()!;
final transformSignals = TransformSignals(transform);

// Reactive position updates
SignalBuilder<double>(
  signal: transformSignals.x,
  builder: (_, x, __) => Text('X: $x'),
);

// Update triggers rebuild
transformSignals.x.value = 100;
```

### WorldSignal

Track entity and system changes:

```dart
final worldSignal = world.toSignal();

// React to entity count
SignalBuilder<int>(
  signal: worldSignal.entityCount,
  builder: (_, count, __) => Text('Entities: $count'),
);

// Query entities reactively
final players = worldSignal.query([TransformComponent, TagComponent]);
```

### ReactiveSystem

Only process entities with dirty components:

```dart
class PlayerMovementSystem extends ReactiveSystem {
  @override
  List<Type> get requiredComponents => [TransformComponent, VelocityComponent];

  @override
  void processEntity(Entity entity, double deltaTime) {
    final transform = entity.getComponent<TransformComponent>()!;
    final velocity = entity.getComponent<VelocityComponent>()!;
    transform.translate(velocity.velocity * deltaTime);
  }
}
```

## Async Support

### AsyncSignal

Handles loading/error/data states:

```dart
final userSignal = AsyncSignal<User>();

// Load data
await userSignal.load(() => api.fetchUser(userId));

// Use in widget
SignalBuilder(
  signal: userSignal,
  builder: (_, snapshot, __) {
    if (snapshot.isLoading) return CircularProgressIndicator();
    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
    return Text('Hello ${snapshot.data!.name}');
  },
);
```

### StreamSignal

Wraps streams with proper lifecycle:

```dart
final messages = StreamSignal(messageStream);

SignalBuilder(
  signal: messages,
  builder: (_, snapshot, __) => Text(snapshot.data?.content ?? ''),
);
```

## Best Practices

1. **Batch related updates** to minimize rebuilds
2. **Use selectors** when you only need part of a signal's data
3. **Pre-allocate arenas** during level loading, not during gameplay
4. **Use ReactiveSystem** for entities that don't change every frame
5. **Dispose signals** when no longer needed to prevent memory leaks

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                      │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │SignalBuilder│ │SignalConsumer│ │ SignalSelector  │  │
│  └──────┬──────┘ └──────┬───────┘ └────────┬────────┘  │
└─────────┼───────────────┼──────────────────┼───────────┘
          │               │                  │
┌─────────┴───────────────┴──────────────────┴───────────┐
│                    Signals Layer                        │
│  ┌──────┐   ┌────────┐   ┌──────┐   ┌───────────────┐  │
│  │Signal│   │Computed│   │Effect│   │ AsyncSignal   │  │
│  └──┬───┘   └───┬────┘   └──┬───┘   └───────────────┘  │
└─────┼───────────┼───────────┼──────────────────────────┘
      │           │           │
┌─────┴───────────┴───────────┴──────────────────────────┐
│                  ECS Integration                        │
│  ┌───────────────┐  ┌────────────┐  ┌──────────────┐   │
│  │ComponentSignal│  │EntitySignal│  │ReactiveSystem│   │
│  └───────────────┘  └────────────┘  └──────────────┘   │
└────────────────────────────────────────────────────────┘
      │
┌─────┴──────────────────────────────────────────────────┐
│                  Memory Layer (Zero-GC)                 │
│  ┌───────────┐    ┌──────────┐    ┌───────────────┐    │
│  │MemoryArena│    │ObjectPool│    │ PoolManager   │    │
│  └───────────┘    └──────────┘    └───────────────┘    │
└────────────────────────────────────────────────────────┘
```

## License

MIT License - see LICENSE file for details.
