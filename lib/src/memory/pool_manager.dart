library;

import 'memory_arena.dart';
import 'object_pool.dart';

/// Central registry for managing all object pools and memory arenas.
///
/// PoolManager follows the service locator pattern used in just_game_engine's
/// SystemManager, providing centralized access to memory resources.
///
/// ```dart
/// final manager = PoolManager();
///
/// // Register pools
/// manager.registerPool<Bullet>('bullets', ObjectPool(
///   create: () => Bullet(),
///   initialSize: 100,
/// ));
///
/// // Access pools
/// final bullet = manager.pool<Bullet>('bullets').acquire();
/// ```
class PoolManager {
  PoolManager._();

  static PoolManager? _instance;

  /// Gets the singleton instance.
  static PoolManager get instance => _instance ??= PoolManager._();

  /// Resets the singleton instance (for testing).
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  final Map<String, ObjectPool<dynamic>> _pools = {};
  final Map<String, MemoryArena> _arenas = {};
  final Map<String, RoundRobinPool<dynamic>> _roundRobinPools = {};

  bool _isDisposed = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // Object Pool Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Registers an object pool with the given name.
  void registerPool<T>(String name, ObjectPool<T> pool) {
    _checkDisposed();
    if (_pools.containsKey(name)) {
      throw StateError('Pool "$name" is already registered');
    }
    _pools[name] = pool;
  }

  /// Gets a registered pool by name.
  ObjectPool<T> pool<T>(String name) {
    _checkDisposed();
    final pool = _pools[name];
    if (pool == null) {
      throw StateError('Pool "$name" is not registered');
    }
    return pool as ObjectPool<T>;
  }

  /// Tries to get a pool, returns null if not found.
  ObjectPool<T>? tryPool<T>(String name) {
    if (_isDisposed) return null;
    return _pools[name] as ObjectPool<T>?;
  }

  /// Checks if a pool is registered.
  bool hasPool(String name) => _pools.containsKey(name);

  /// Removes a pool registration.
  void unregisterPool(String name) {
    _pools.remove(name);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Memory Arena Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Registers a memory arena with the given name.
  void registerArena(String name, MemoryArena arena) {
    _checkDisposed();
    if (_arenas.containsKey(name)) {
      throw StateError('Arena "$name" is already registered');
    }
    _arenas[name] = arena;
  }

  /// Creates and registers a memory arena.
  MemoryArena createArena(
    String name, {
    required int capacity,
    int componentsPerEntity = 8,
  }) {
    final arena = MemoryArena(
      capacity: capacity,
      componentsPerEntity: componentsPerEntity,
    );
    registerArena(name, arena);
    return arena;
  }

  /// Gets a registered arena by name.
  MemoryArena arena(String name) {
    _checkDisposed();
    final arena = _arenas[name];
    if (arena == null) {
      throw StateError('Arena "$name" is not registered');
    }
    return arena;
  }

  /// Tries to get an arena, returns null if not found.
  MemoryArena? tryArena(String name) {
    if (_isDisposed) return null;
    return _arenas[name];
  }

  /// Checks if an arena is registered.
  bool hasArena(String name) => _arenas.containsKey(name);

  /// Removes an arena registration.
  void unregisterArena(String name) {
    _arenas.remove(name);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Round Robin Pool Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Registers a round-robin pool with the given name.
  void registerRoundRobin<T>(String name, RoundRobinPool<T> pool) {
    _checkDisposed();
    if (_roundRobinPools.containsKey(name)) {
      throw StateError('RoundRobinPool "$name" is already registered');
    }
    _roundRobinPools[name] = pool;
  }

  /// Creates and registers a round-robin pool.
  RoundRobinPool<T> createRoundRobin<T>(
    String name, {
    required T Function() create,
    required int size,
    void Function(T)? onRecycle,
  }) {
    final pool = RoundRobinPool<T>(
      create: create,
      size: size,
      onRecycle: onRecycle,
    );
    registerRoundRobin(name, pool);
    return pool;
  }

  /// Gets a registered round-robin pool by name.
  RoundRobinPool<T> roundRobin<T>(String name) {
    _checkDisposed();
    final pool = _roundRobinPools[name];
    if (pool == null) {
      throw StateError('RoundRobinPool "$name" is not registered');
    }
    return pool as RoundRobinPool<T>;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Statistics & Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets statistics about all pools.
  Map<String, PoolStats> getPoolStats() {
    final stats = <String, PoolStats>{};
    for (final entry in _pools.entries) {
      stats[entry.key] = PoolStats(
        available: entry.value.availableCount,
        inUse: entry.value.inUseCount,
        totalCreated: entry.value.totalCreated,
      );
    }
    return stats;
  }

  /// Gets statistics about all arenas.
  Map<String, ArenaStats> getArenaStats() {
    final stats = <String, ArenaStats>{};
    for (final entry in _arenas.entries) {
      stats[entry.key] = ArenaStats(
        capacity: entry.value.capacity,
        allocated: entry.value.allocatedCount,
        available: entry.value.availableCount,
      );
    }
    return stats;
  }

  /// Releases all objects in all pools.
  void releaseAllPools() {
    for (final pool in _pools.values) {
      pool.releaseAll();
    }
  }

  /// Clears all arenas.
  void clearAllArenas() {
    for (final arena in _arenas.values) {
      arena.clear();
    }
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('PoolManager has been disposed');
    }
  }

  /// Disposes all pools and arenas.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final pool in _pools.values) {
      pool.clear();
    }
    _pools.clear();

    for (final arena in _arenas.values) {
      arena.clear();
    }
    _arenas.clear();

    _roundRobinPools.clear();
  }

  /// Whether this manager has been disposed.
  bool get isDisposed => _isDisposed;
}

/// Statistics for an object pool.
class PoolStats {
  const PoolStats({
    required this.available,
    required this.inUse,
    required this.totalCreated,
  });

  final int available;
  final int inUse;
  final int totalCreated;

  int get total => available + inUse;

  @override
  String toString() =>
      'PoolStats(available: $available, inUse: $inUse, total: $totalCreated)';
}

/// Statistics for a memory arena.
class ArenaStats {
  const ArenaStats({
    required this.capacity,
    required this.allocated,
    required this.available,
  });

  final int capacity;
  final int allocated;
  final int available;

  double get utilizationPercent =>
      capacity > 0 ? (allocated / capacity) * 100 : 0;

  @override
  String toString() =>
      'ArenaStats(capacity: $capacity, allocated: $allocated, utilization: ${utilizationPercent.toStringAsFixed(1)}%)';
}
