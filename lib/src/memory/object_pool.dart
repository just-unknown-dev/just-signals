library;

/// A generic object pool for reusing objects and avoiding allocations.
///
/// Object pools pre-allocate objects and recycle them to prevent
/// garbage collection pressure during gameplay.
///
/// ```dart
/// final bulletPool = ObjectPool<Bullet>(
///   create: () => Bullet(),
///   reset: (b) => b.reset(),
///   initialSize: 100,
/// );
///
/// final bullet = bulletPool.acquire();
/// // ... use bullet
/// bulletPool.release(bullet);
/// ```
class ObjectPool<T> {
  /// Creates an object pool.
  ///
  /// [create] is called to instantiate new objects.
  /// [reset] is called when an object is released back to the pool.
  /// [initialSize] pre-allocates this many objects.
  /// [maxSize] limits the pool size (0 = unlimited).
  ObjectPool({
    required this.create,
    this.reset,
    this.onAcquire,
    int initialSize = 0,
    int maxSize = 0,
  }) : _maxSize = maxSize {
    _prewarm(initialSize);
  }

  /// Factory function to create new instances.
  final T Function() create;

  /// Called when an object is released to reset its state.
  final void Function(T object)? reset;

  /// Called when an object is acquired from the pool.
  final void Function(T object)? onAcquire;

  final int _maxSize;
  final List<T> _available = [];
  final Set<T> _inUse = {};

  int _totalCreated = 0;

  /// Pre-warms the pool with objects.
  void _prewarm(int count) {
    for (var i = 0; i < count; i++) {
      _available.add(_createNew());
    }
  }

  T _createNew() {
    _totalCreated++;
    return create();
  }

  /// Acquires an object from the pool.
  ///
  /// If no objects are available, a new one is created.
  T acquire() {
    final T object;

    if (_available.isNotEmpty) {
      object = _available.removeLast();
    } else {
      object = _createNew();
    }

    _inUse.add(object);
    onAcquire?.call(object);
    return object;
  }

  /// Releases an object back to the pool.
  ///
  /// The reset function is called to clear the object's state.
  void release(T object) {
    if (!_inUse.remove(object)) {
      return; // Object wasn't from this pool or already released
    }

    reset?.call(object);

    if (_maxSize == 0 || _available.length < _maxSize) {
      _available.add(object);
    }
    // If at max size, object is discarded (will be GC'd)
  }

  /// Releases all objects currently in use.
  void releaseAll() {
    for (final object in _inUse.toList()) {
      release(object);
    }
  }

  /// The number of available objects in the pool.
  int get availableCount => _available.length;

  /// The number of objects currently in use.
  int get inUseCount => _inUse.length;

  /// The total number of objects created by this pool.
  int get totalCreated => _totalCreated;

  /// The total size (available + in use).
  int get totalSize => _available.length + _inUse.length;

  /// Pre-warms additional objects.
  void prewarm(int count) => _prewarm(count);

  /// Shrinks the available pool to the given size.
  void shrink(int targetSize) {
    while (_available.length > targetSize) {
      _available.removeLast();
    }
  }

  /// Clears the pool completely.
  void clear() {
    _available.clear();
    _inUse.clear();
  }
}

/// A pool that uses a round-robin approach for fixed-size scenarios.
///
/// Useful when you want to limit the maximum concurrent objects
/// and automatically recycle the oldest one when the limit is reached.
///
/// ```dart
/// final sfxPool = RoundRobinPool<AudioPlayer>(
///   create: () => AudioPlayer(),
///   size: 10,
/// );
///
/// final player = sfxPool.next(); // Gets next in rotation
/// ```
class RoundRobinPool<T> {
  RoundRobinPool({
    required T Function() create,
    required int size,
    this.onRecycle,
  }) : _pool = List.generate(size, (_) => create());

  final List<T> _pool;
  final void Function(T object)? onRecycle;
  int _index = 0;

  /// Gets the next object in the rotation.
  T next() {
    final object = _pool[_index];
    onRecycle?.call(object);
    _index = (_index + 1) % _pool.length;
    return object;
  }

  /// Gets an object at a specific index.
  T at(int index) => _pool[index % _pool.length];

  /// The size of the pool.
  int get size => _pool.length;

  /// The current index.
  int get currentIndex => _index;

  /// Resets the index to 0.
  void reset() => _index = 0;

  /// Iterates over all objects.
  void forEach(void Function(T object) callback) {
    for (final object in _pool) {
      callback(object);
    }
  }
}

/// A pool with priority-based eviction.
///
/// When acquiring and the pool is empty, evicts the lowest priority
/// in-use object if possible.
class PriorityPool<T> {
  PriorityPool({
    required this.create,
    this.reset,
    this.getPriority,
    int initialSize = 0,
  }) {
    for (var i = 0; i < initialSize; i++) {
      _available.add(create());
    }
  }

  final T Function() create;
  final void Function(T object)? reset;
  final int Function(T object)? getPriority;

  final List<T> _available = [];
  final Set<T> _inUse = {};

  /// Acquires an object, potentially evicting a low-priority one.
  T acquire({int minPriority = 0}) {
    if (_available.isNotEmpty) {
      final object = _available.removeLast();
      _inUse.add(object);
      return object;
    }

    // Try to evict lowest priority
    if (_inUse.isNotEmpty && getPriority != null) {
      T? lowest;
      int lowestPriority = minPriority;

      for (final object in _inUse) {
        final priority = getPriority!(object);
        if (priority < lowestPriority) {
          lowest = object;
          lowestPriority = priority;
        }
      }

      if (lowest != null) {
        _inUse.remove(lowest);
        reset?.call(lowest);
        _inUse.add(lowest);
        return lowest;
      }
    }

    // Create new
    final object = create();
    _inUse.add(object);
    return object;
  }

  void release(T object) {
    if (_inUse.remove(object)) {
      reset?.call(object);
      _available.add(object);
    }
  }

  int get availableCount => _available.length;
  int get inUseCount => _inUse.length;
}
