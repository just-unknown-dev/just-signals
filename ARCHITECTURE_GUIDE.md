# Building Architecture with just_signals

A practical guide to structuring reactive, data-driven applications using the
`just_signals` package — from small state objects to full game architectures.

---

## Table of Contents

1. [Core Concepts](#1-core-concepts)
2. [Signal Primitives](#2-signal-primitives)
3. [Derived State with Computed](#3-derived-state-with-computed)
4. [Side Effects with Effect](#4-side-effects-with-effect)
5. [Batching and Transactions](#5-batching-and-transactions)
6. [Selectors — Surgical Precision](#6-selectors--surgical-precision)
7. [State Container Pattern](#7-state-container-pattern)
8. [Flutter UI Integration](#8-flutter-ui-integration)
9. [Async State](#9-async-state)
10. [ECS Integration](#10-ecs-integration)
11. [Memory Layer](#11-memory-layer)
12. [Full Game Architecture](#12-full-game-architecture)
13. [Patterns and Anti-Patterns](#13-patterns-and-anti-patterns)
14. [Layer Diagram](#14-layer-diagram)

---

## 1. Core Concepts

`just_signals` is built on three reactive primitives:

| Primitive    | Purpose                                     | Notifies when…            |
|--------------|---------------------------------------------|---------------------------|
| `Signal<T>`  | Mutable reactive value                      | `.value` is set to a new value |
| `Computed<T>`| Derived value, lazily re-evaluated          | Any tracked dependency changes |
| `Effect`     | Side effect that auto-tracks its own deps   | Any accessed signal changes |

All three implement `ValueListenable<T>` and integrate cleanly with Flutter's
widget rebuild system.

**Dependency tracking is automatic.** When code inside a `Computed` or `Effect`
reads a signal's `.value`, that signal is silently registered as a dependency.
No decorators, no `watch()` calls, no explicit subscription lists required.

---

## 2. Signal Primitives

### Creating signals

```dart
// Basic signal with initial value
final score = Signal<int>(0);

// With a debug label (shown in Flutter DevTools)
final health = Signal<int>(100, debugLabel: 'playerHealth');

// Any type
final phase = Signal<GamePhase>(GamePhase.loading);
final position = Signal<Offset>(Offset.zero);
final playerName = Signal<String>('Player');
```

### Reading and writing

```dart
// Read
print(score.value); // 0

// Write (notifies listeners only if value changed)
score.value = 250;

// Update using previous value
score.update((current) => current + 50);

// Force notification even if value is unchanged
score.forceNotify();
```

### Adding listeners manually

Only needed when you cannot use `SignalBuilder` (e.g. from game-loop code):

```dart
void _onScoreChanged() {
  print('New score: ${score.value}');
}

score.addListener(_onScoreChanged);
// …later
score.removeListener(_onScoreChanged);
```

---

## 3. Derived State with Computed

`Computed<T>` derives its value from one or more signals. It re-evaluates
lazily (only on access, and only when dirty) and caches the result.

### Single-dependency computed

```dart
final health = Signal<int>(100);
final maxHealth = Signal<int>(100);

// Automatically re-computes when health or maxHealth changes
final healthPercent = Computed<double>(
  () => health.value / maxHealth.value,
  debugLabel: 'healthPercent',
);

print(healthPercent.value); // 1.0
health.value = 40;
print(healthPercent.value); // 0.4
```

### Multi-dependency computed

```dart
final wave = Signal<int>(1);
final enemiesDefeated = Signal<int>(0);

final waveText = Computed<String>(
  () => 'Wave ${wave.value}  ·  ${enemiesDefeated.value} kills',
);
```

### Chained computed values

```dart
final rawScore = Signal<int>(0);
final multiplier = Signal<double>(1.0);

final adjustedScore = Computed<int>(
  () => (rawScore.value * multiplier.value).round(),
);

// healthColorArgb derived from adjustedScore (itself derived)
final displayColor = Computed<Color>(() {
  final pct = adjustedScore.value / 1000.0;
  return Color.lerp(Colors.red, Colors.green, pct.clamp(0, 1))!;
});
```

### Selector extension (partial rebuild)

When a signal holds a complex object, rebuild only when the relevant field changes:

```dart
final user = Signal<User>(User(name: 'John', score: 0));

// Only triggers rebuild when name changes — score changes are ignored
final userName = user.select((u) => u.name);

// Use in widget
SignalBuilder<String>(
  signal: userName,
  builder: (_, name, __) => Text(name),
);
```

### Combining multiple signals into one value

```dart
final a = Signal<int>(10);
final b = Signal<int>(20);

final sum = combine2(a, b, (x, y) => x + y);
// sum.value == 30
```

---

## 4. Side Effects with Effect

Use `Effect` for any logic that should run in response to signal changes but
does not produce a UI widget — logging, audio, persistence, analytics.

```dart
final phase = Signal<GamePhase>(GamePhase.loading);

// Runs immediately, then again whenever phase changes
final phaseEffect = Effect(() {
  print('Phase changed to: ${phase.value}');

  // Optional cleanup — runs before the next re-execution and on dispose()
  return () => print('Cleaning up previous phase');
});

phase.value = GamePhase.playing;
// → "Cleaning up previous phase"
// → "Phase changed to: GamePhase.playing"

phaseEffect.dispose();
```

### Effect with multiple dependencies

```dart
final health = Signal<int>(100);
final lives = Signal<int>(3);

final deathEffect = Effect(() {
  if (health.value <= 0 && lives.value > 0) {
    _respawnPlayer();
  } else if (health.value <= 0 && lives.value == 0) {
    _triggerGameOver();
  }
});
```

### Deferred (non-immediate) effects

```dart
// immediate: false → only runs when a dependency actually changes,
// not at construction time
final saveEffect = Effect(
  () => _saveScoreToStorage(score.value),
  immediate: false,
);
```

---

## 5. Batching and Transactions

### `batch()` — defer all notifications until done

Without batching, every individual signal write fires its own set of listener
callbacks. With `batch()`, listeners are collected and fired once at the end.

```dart
// Without batch: wave widget rebuilds, then enemies widget rebuilds separately
wave.value = 2;
maxEnemies.value = 7;

// With batch: one combined rebuild pass
batch(() {
  wave.value = 2;
  maxEnemies.value = 7;
  spawnInterval.value = 3.5;
});
```

Use `SignalBatch.run()` for the same effect from non-top-level code:

```dart
void advanceWave() {
  SignalBatch.run(() {
    wave.update((w) => w + 1);
    maxEnemies.update((m) => m + 1);
    spawnInterval.update((i) => (i - 0.1).clamp(1.5, 4.0));
    score.update((s) => s + waveClearBonus);
    statusMessage.value = 'Wave ${wave.value} complete!';
  });
}
```

### `transaction()` — rollback on error

```dart
transaction(() {
  playerGold.value -= cost;
  if (playerGold.value < 0) throw InsufficientFundsException();
  itemInventory.update((inv) => [...inv, item]);
});
// If the exception is thrown, playerGold is restored to its pre-transaction value.
```

---

## 6. Selectors — Surgical Precision

Selectors let you subscribe to one field of a larger object without rebuilding
on unrelated field changes.

```dart
final settings = Signal<AppSettings>(AppSettings.defaults());

// Each selector is independent — changing volume won't rebuild the name field
final playerName  = settings.select((s) => s.playerName);
final musicVolume = settings.select((s) => s.musicVolume);
final showFps     = settings.select((s) => s.showFps);
```

`selectMany` creates multiple selectors in one call:

```dart
final [nameSignal, volumeSignal] = settings.selectMany([
  (s) => s.playerName,
  (s) => s.musicVolume,
]);
```

---

## 7. State Container Pattern

Collect all related signals into a plain Dart class. This is the recommended
architecture for any non-trivial application.

```dart
class GameState {
  // ── Mutable signals ──────────────────────────────────────────────────────
  final phase    = Signal<GamePhase>(GamePhase.loading, debugLabel: 'phase');
  final score    = Signal<int>(0,   debugLabel: 'score');
  final health   = Signal<int>(100, debugLabel: 'health');
  final maxHealth= Signal<int>(100, debugLabel: 'maxHealth');
  final lives    = Signal<int>(3,   debugLabel: 'lives');
  final wave     = Signal<int>(1,   debugLabel: 'wave');

  // ── Computed (derived, no direct mutation) ────────────────────────────────
  late final Computed<double> healthPercent;
  late final Computed<String> waveText;
  late final Computed<bool>   isAlive;
  late final Computed<int>    healthColorArgb;

  GameState() {
    healthPercent = Computed(
      () => health.value / maxHealth.value.clamp(1, double.infinity),
    );
    waveText = Computed(() => 'Wave ${wave.value}');
    isAlive  = Computed(() => health.value > 0 && lives.value > 0);
    healthColorArgb = Computed(() {
      final pct = healthPercent.value;
      if (pct > 0.6) return 0xFF4CAF50; // green
      if (pct > 0.3) return 0xFFFF9800; // orange
      return 0xFFF44336;                // red
    });
  }

  // ── Mutating actions (always batch related changes) ───────────────────────

  void takeDamage(int amount) {
    SignalBatch.run(() {
      health.update((h) => (h - amount).clamp(0, maxHealth.value));
      if (health.value == 0) {
        lives.update((l) => l - 1);
        if (lives.value <= 0) phase.value = GamePhase.gameOver;
      }
    });
  }

  void collectCoin() {
    SignalBatch.run(() {
      score.update((s) => s + 50);
    });
  }

  void advanceWave() {
    SignalBatch.run(() {
      wave.update((w) => w + 1);
      score.update((s) => s + 500);
    });
  }

  void reset() {
    SignalBatch.run(() {
      phase.value    = GamePhase.loading;
      score.value    = 0;
      health.value   = maxHealth.value;
      lives.value    = 3;
      wave.value     = 1;
    });
  }
}
```

**Rules:**
- Raw signals are **read–write** only within the state class itself.
- Expose signals as `final` fields (readable everywhere).
- All multi-signal mutations go through an **action method** that uses `batch()`.
- Computed values are **never** set from outside — they derive automatically.

---

## 8. Flutter UI Integration

### `SignalBuilder<T>` — rebuild a single widget

```dart
SignalBuilder<int>(
  signal: state.score,
  builder: (context, score, child) => Text(
    '$score',
    style: const TextStyle(fontSize: 24, color: Colors.white),
  ),
),
```

The `child` parameter is passed through unchanged — use it for expensive
sub-trees that don't depend on the signal:

```dart
SignalBuilder<bool>(
  signal: state.isPlaying,
  child: const GameCanvas(),          // built once, never rebuilt
  builder: (context, isPlaying, canvas) => isPlaying
      ? canvas!
      : const LoadingSpinner(),
),
```

### `SignalConsumer` — rebuild on any of N signals

```dart
SignalConsumer(
  signals: [state.health, state.maxHealth, state.healthColorArgb],
  builder: (context, child) => LinearProgressIndicator(
    value: state.healthPercent.value,
    color: Color(state.healthColorArgb.value),
  ),
),
```

### `SignalSelector<T, R>` — partial rebuild from a complex signal

```dart
// Only rebuilds when the player's name changes, not other user fields
SignalSelector<User, String>(
  signal: userSignal,
  selector: (user) => user.name,
  builder: (context, name, child) => Text('Player: $name'),
),
```

### Pattern: HUD composed of independent signal slices

Each widget only rebuilds when its specific signal slice changes.
Unrelated HUD elements remain frozen.

```dart
class GameHud extends StatelessWidget {
  final GameState state;

  const GameHud({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Rebuilds only on score changes
        SignalBuilder<int>(
          signal: state.score,
          builder: (_, score, __) => _ScoreDisplay(score: score),
        ),

        // Rebuilds only on health/maxHealth/color changes
        SignalConsumer(
          signals: [state.health, state.maxHealth, state.healthColorArgb],
          builder: (_, __) => _HealthBar(state: state),
        ),

        // Rebuilds only on wave changes
        SignalBuilder<String>(
          signal: state.waveText,
          builder: (_, text, __) => _WaveLabel(text: text),
        ),
      ],
    );
  }
}
```

---

## 9. Async State

### `AsyncSignal<T>` — loading / error / data states

```dart
final leaderboard = AsyncSignal<List<Score>>();

// Load from network or database
await leaderboard.load(() => db.getTopScores(limit: 10));

// In the widget tree
SignalBuilder(
  signal: leaderboard,
  builder: (_, snapshot, __) {
    if (snapshot.isLoading) return const CircularProgressIndicator();
    if (snapshot.hasError)  return Text('Error: ${snapshot.error}');
    return ScoreList(scores: snapshot.data!);
  },
),
```

### `StreamSignal<T>` — wrap a stream

```dart
final storageUpdates = StreamSignal(storage.watch('settings'));

SignalBuilder(
  signal: storageUpdates,
  builder: (_, snapshot, __) => SettingsPanel(data: snapshot.data),
),
```

### `FutureSignal<T>` — one-shot async value

```dart
final playerName = FutureSignal(storage.getPlayerName());

SignalBuilder(
  signal: playerName,
  builder: (_, snapshot, __) =>
      Text(snapshot.data ?? 'Loading player name…'),
),
```

---
### `ComponentSignal` — reactive component access

```dart
final transform = entity.getComponent<TransformComponent>()!;
final ts = TransformSignals(transform);

// Rebuild only when x coordinate changes
SignalBuilder<double>(
  signal: ts.x,
  builder: (_, x, __) => Text('X: ${x.toStringAsFixed(1)}'),
);

// Updating the signal also updates the underlying component
ts.x.value = 150.0;
```

### `WorldSignal` — reactive entity queries

```dart
final worldSignal = engine.world.toSignal();

// Reactive entity count
SignalBuilder<int>(
  signal: worldSignal.entityCount,
  builder: (_, count, __) => Text('Entities: $count'),
);

// Query all enemies reactively
final enemies = worldSignal.query([TransformComponent, TagComponent]);
```

### `ReactiveSystem` — only process changed entities

```dart
class EnemyAISystem extends ReactiveSystem {
  @override
  List<Type> get requiredComponents => [TransformComponent, TagComponent];

  @override
  void processEntity(Entity entity, double deltaTime) {
    final transform = entity.getComponent<TransformComponent>()!;
    final tag       = entity.getComponent<TagComponent>()!;
    if (tag.tag != 'enemy') return;

    // Move toward player — only called for entities that changed this tick
    _moveTowardPlayer(transform, deltaTime);
  }
}
```

Using `ReactiveSystem` instead of base `System` skips entities whose
components have not been dirtied since the last tick — important for
maintaining performance at high entity counts.

---

## 11. Memory Layer

For 60 FPS loops, avoid allocating objects in hot paths. Use the memory layer
for particle systems, bullet pools, and entity data arrays.

### `MemoryArena` — pre-allocated typed arrays

```dart
// Allocate space for up to 500 entities — done once at level load
final arena = MemoryArena(capacity: 500);

// Acquire a slot — no heap allocation
final slot = arena.allocate();

// Modify in place
arena.setPosition(slot, 100.0, 200.0);
arena.setVelocity(slot, 50.0, -30.0);

// Per-frame: integrate velocity — no allocation
arena.applyVelocity(slot, deltaTime);

// Release when entity dies
arena.free(slot);
```

### `ObjectPool<T>` — reuse expensive objects

```dart
final bulletPool = ObjectPool<Bullet>(
  create: () => Bullet(),
  reset: (b) => b.reset(),
  initialSize: 200, // Pre-warm the pool
);

// Acquire — returns a reset object, no allocation after warm-up
final bullet = bulletPool.acquire();
bullet.init(origin: playerPos, direction: aimDir, speed: 800);

// Release on impact — back to pool, no GC pressure
bulletPool.release(bullet);
```

### `PoolManager` — centralized pool registry

```dart
final pools = PoolManager();

pools.register<Bullet>(
  'bullets',
  ObjectPool<Bullet>(create: () => Bullet(), reset: (b) => b.reset()),
);

pools.register<Particle>(
  'particles',
  ObjectPool<Particle>(
    create: () => Particle(),
    reset: (p) => p.reset(),
    initialSize: 500,
  ),
);

// Usage from anywhere
final bullet   = pools.acquire<Bullet>('bullets');
final particle = pools.acquire<Particle>('particles');
```

---

## 12. Full Game Architecture

Below is the recommended layered architecture for a Flutter game using
`just_signals` + `just_game_engine`.

```
┌─────────────────────────────────────────────────────────────────────┐
│  Flutter UI Layer   (game_page.dart, home_page.dart, …)             │
│                                                                     │
│  ┌───────────────┐  ┌────────────────┐  ┌──────────────────────┐   │
│  │ SignalBuilder │  │ SignalConsumer  │  │  SignalSelector      │   │
│  │  (1 signal)   │  │  (N signals)   │  │  (field of signal)   │   │
│  └───────┬───────┘  └───────┬────────┘  └──────────┬───────────┘   │
└──────────┼──────────────────┼────────────────────────┼─────────────┘
           │                  │                        │
┌──────────▼──────────────────▼────────────────────────▼─────────────┐
│  State Layer   (GameState, SettingsState, …)        [just_signals]  │
│                                                                     │
│  Signal<T>   Computed<T>   Effect   batch()   transaction()         │
│                                                                     │
│  • All mutable primitives live here                                 │
│  • Computed derives values automatically                            │
│  • Action methods batch all related mutation                        │
└─────────────────────────────────────────────────────────────────────┘
           │                  │
┌──────────▼──────────────────▼─────────────────────────────────────┐
│  Game Logic Layer   (DemoGame, systems, …)          [just_signals] │
│                                                                     │
│  • Reads / writes Signals via GameState                            │
│  • Uses addListener() for game-loop callbacks                      │
│  • ECS Systems call state.takeDamage(), state.collectCoin(), …     │
└─────────────────────────────────────────────────────────────────────┘
           │                  │
┌──────────▼──────────────────▼─────────────────────────────────────┐
│  ECS Integration Layer                          [just_game_engine] │
│                                                                     │
│  ComponentSignal   EntitySignal   WorldSignal   ReactiveSystem      │
│  (depends on just_signals — not vice versa)                        │
└─────────────────────────────────────────────────────────────────────┘
           │
┌──────────▼─────────────────────────────────────────────────────────┐
│  Memory Layer (Zero-GC)                             [just_signals] │
│                                                                     │
│  MemoryArena   ObjectPool<T>   PoolManager   TypedBuffer            │
└────────────────────────────────────────────────────────────────────┘
```

### Wiring it together

```dart
// main.dart — create engine and inject state top-down
void main() async {
  final engine = Engine();
  await engine.initialize();
  runApp(MyApp(engine: engine));
}

// game_page.dart — create state once per game session
class _GamePageState extends State<GamePage> {
  late final GameState _state;
  late final DemoGame _game;

  @override
  void initState() {
    super.initState();
    _state = GameState();
    _game  = DemoGame(engine: widget.engine, state: _state);
    _game.setup();
  }
}

// demo_game.dart — mutate state via action methods
void _onCoinCollected(Offset position) {
  state.collectCoin();          // batches score update internally
}

void _onPlayerHit(Entity enemy) {
  state.takeDamage(_contactDamage);   // batches health + lives + phase
}

// game_page.dart — react to state surgically
SignalBuilder<int>(
  signal: _state.score,
  builder: (_, score, __) => Text('$score'),
),
```

---

## 13. Patterns and Anti-Patterns

### ✅ Good patterns

**Batch all related mutations**
```dart
// Good — one rebuild pass
void collectPowerUp() {
  SignalBatch.run(() {
    health.update((h) => (h + 30).clamp(0, maxHealth.value));
    score.update((s) => s + 200);
    statusMessage.value = 'Power-up collected!';
  });
}
```

**Use Computed for any derived value**
```dart
// Good — always consistent, zero manual sync
final isGameOver = Computed(() => health.value <= 0 && lives.value <= 0);
```

**Use `debugLabel` during development**
```dart
final wave = Signal<int>(1, debugLabel: 'currentWave');
```

**Dispose effects when done**
```dart
@override
void dispose() {
  _playerEffect.dispose();
  _audioEffect.dispose();
  super.dispose();
}
```

---

### ❌ Anti-patterns

**Never mutate computed values**
```dart
// WRONG — Computed has no setter
healthPercent.value = 0.5;
```

**Never scatter signal writes without batching**
```dart
// BAD — fires 3 separate rebuild passes
wave.value++;
maxEnemies.value++;
spawnInterval.value -= 0.1;

// GOOD — fires 1 rebuild pass
batch(() {
  wave.update((w) => w + 1);
  maxEnemies.update((m) => m + 1);
  spawnInterval.update((i) => i - 0.1);
});
```

**Never read signals inside constructors without lazy init**
```dart
// BAD — isAlive computed runs during construction,
// but health not yet fully initialised
final isAlive = Computed(() => health.value > 0); // may fail

// GOOD — use late
late final Computed<bool> isAlive;
GameState() {
  isAlive = Computed(() => health.value > 0);
}
```

**Never allocate inside game-loop hot paths**
```dart
// BAD — Offset allocation every frame
void update(double dt) {
  position.value = Offset(x + vx * dt, y + vy * dt); // new Offset each frame
}

// GOOD — use MemoryArena or update components in place
arena.applyVelocity(slot, dt);
```

---

## 14. Layer Diagram

```
just_signals Architecture
══════════════════════════════════════════════════════════════════════

  WRITE           Action methods (batch / transaction)
    │                         │
    ▼                         ▼
  Signal<T> ──────────────► Computed<T>  ◄── auto-tracked deps
    │                         │
    │         ┌───────────────┘
    │         │
    ▼         ▼
  Effect  (side effects: audio, storage, logging)

    │         │
    └────┬────┘
         │
         ▼
  SignalBuilder / SignalConsumer / SignalSelector
  (Flutter widget rebuild — only affected widgets)

══════════════════════════════════════════════════════════════════════
  ZERO-GC LAYER (below the signal graph)

  ObjectPool<T>    MemoryArena    TypedBuffer    PoolManager
  (particle/bullet pools, entity position arrays — no heap churn)
══════════════════════════════════════════════════════════════════════
```

---

*Guide version 1.0 · just_signals 1.0 · just_game_engine demo*
