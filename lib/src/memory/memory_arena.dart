library;

import 'dart:typed_data';

/// A pre-allocated memory arena for storing entity data contiguously.
///
/// Memory arenas prevent garbage collection pressure by pre-allocating
/// large typed arrays and modifying them in-place. This is crucial for
/// maintaining 60 FPS in game loops.
///
/// Uses Struct-of-Arrays (SoA) layout for better cache locality.
///
/// ```dart
/// final arena = MemoryArena(capacity: 1000);
/// final slot = arena.allocate();
/// arena.setPosition(slot, 100.0, 200.0);
/// // ... game loop modifies in place
/// arena.free(slot);
/// ```
class MemoryArena {
  /// Creates a memory arena with the given capacity.
  ///
  /// [capacity] is the maximum number of entities that can be stored.
  /// [componentsPerEntity] defines how many float values per entity slot.
  MemoryArena({required int capacity, int componentsPerEntity = 8})
    : _capacity = capacity,
      _componentsPerEntity = componentsPerEntity,
      _data = Float64List(capacity * componentsPerEntity),
      _allocated = List<bool>.filled(capacity, false),
      _freeList = List<int>.generate(capacity, (i) => capacity - 1 - i);

  final int _capacity;
  final int _componentsPerEntity;
  final Float64List _data;
  final List<bool> _allocated;
  final List<int> _freeList;

  int _allocatedCount = 0;
  int _freeListTop = 0;

  /// Standard component offsets within each entity slot.
  static const int offsetX = 0;
  static const int offsetY = 1;
  static const int offsetRotation = 2;
  static const int offsetScaleX = 3;
  static const int offsetScaleY = 4;
  static const int offsetVelocityX = 5;
  static const int offsetVelocityY = 6;
  static const int offsetExtra = 7;

  /// The maximum capacity of this arena.
  int get capacity => _capacity;

  /// The number of currently allocated slots.
  int get allocatedCount => _allocatedCount;

  /// The number of available slots.
  int get availableCount => _capacity - _allocatedCount;

  /// Whether the arena is full.
  bool get isFull => _allocatedCount >= _capacity;

  /// Allocates a slot and returns its index.
  ///
  /// Returns -1 if the arena is full.
  int allocate() {
    if (_freeListTop >= _capacity) {
      return -1; // Arena full
    }

    final slot = _freeList[_freeListTop++];
    _allocated[slot] = true;
    _allocatedCount++;

    // Initialize slot to zeros
    final base = slot * _componentsPerEntity;
    for (var i = 0; i < _componentsPerEntity; i++) {
      _data[base + i] = 0.0;
    }

    return slot;
  }

  /// Frees a previously allocated slot.
  void free(int slot) {
    if (slot < 0 || slot >= _capacity || !_allocated[slot]) {
      return;
    }

    _allocated[slot] = false;
    _freeList[--_freeListTop] = slot;
    _allocatedCount--;
  }

  /// Checks if a slot is allocated.
  bool isAllocated(int slot) {
    return slot >= 0 && slot < _capacity && _allocated[slot];
  }

  /// Gets the base index for a slot's data.
  int _baseIndex(int slot) => slot * _componentsPerEntity;

  // ═══════════════════════════════════════════════════════════════════════════
  // Position accessors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets the X position of a slot.
  double getX(int slot) => _data[_baseIndex(slot) + offsetX];

  /// Gets the Y position of a slot.
  double getY(int slot) => _data[_baseIndex(slot) + offsetY];

  /// Sets the position of a slot.
  void setPosition(int slot, double x, double y) {
    final base = _baseIndex(slot);
    _data[base + offsetX] = x;
    _data[base + offsetY] = y;
  }

  /// Translates a slot's position.
  void translate(int slot, double dx, double dy) {
    final base = _baseIndex(slot);
    _data[base + offsetX] += dx;
    _data[base + offsetY] += dy;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Rotation accessors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets the rotation of a slot (radians).
  double getRotation(int slot) => _data[_baseIndex(slot) + offsetRotation];

  /// Sets the rotation of a slot (radians).
  void setRotation(int slot, double rotation) {
    _data[_baseIndex(slot) + offsetRotation] = rotation;
  }

  /// Rotates a slot by the given angle.
  void rotate(int slot, double angle) {
    _data[_baseIndex(slot) + offsetRotation] += angle;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Scale accessors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets the X scale of a slot.
  double getScaleX(int slot) => _data[_baseIndex(slot) + offsetScaleX];

  /// Gets the Y scale of a slot.
  double getScaleY(int slot) => _data[_baseIndex(slot) + offsetScaleY];

  /// Sets the uniform scale of a slot.
  void setScale(int slot, double scale) {
    final base = _baseIndex(slot);
    _data[base + offsetScaleX] = scale;
    _data[base + offsetScaleY] = scale;
  }

  /// Sets the non-uniform scale of a slot.
  void setScaleXY(int slot, double scaleX, double scaleY) {
    final base = _baseIndex(slot);
    _data[base + offsetScaleX] = scaleX;
    _data[base + offsetScaleY] = scaleY;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Velocity accessors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets the X velocity of a slot.
  double getVelocityX(int slot) => _data[_baseIndex(slot) + offsetVelocityX];

  /// Gets the Y velocity of a slot.
  double getVelocityY(int slot) => _data[_baseIndex(slot) + offsetVelocityY];

  /// Sets the velocity of a slot.
  void setVelocity(int slot, double vx, double vy) {
    final base = _baseIndex(slot);
    _data[base + offsetVelocityX] = vx;
    _data[base + offsetVelocityY] = vy;
  }

  /// Applies velocity to position (for movement system).
  void applyVelocity(int slot, double deltaTime) {
    final base = _baseIndex(slot);
    _data[base + offsetX] += _data[base + offsetVelocityX] * deltaTime;
    _data[base + offsetY] += _data[base + offsetVelocityY] * deltaTime;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Extra/generic accessors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets a raw value at an offset within a slot.
  double getValue(int slot, int offset) {
    return _data[_baseIndex(slot) + offset];
  }

  /// Sets a raw value at an offset within a slot.
  void setValue(int slot, int offset, double value) {
    _data[_baseIndex(slot) + offset] = value;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Batch operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Copies data from one slot to another.
  void copySlot(int from, int to) {
    final fromBase = _baseIndex(from);
    final toBase = _baseIndex(to);
    for (var i = 0; i < _componentsPerEntity; i++) {
      _data[toBase + i] = _data[fromBase + i];
    }
  }

  /// Applies velocity to all allocated slots.
  void applyVelocityAll(double deltaTime) {
    for (var slot = 0; slot < _capacity; slot++) {
      if (_allocated[slot]) {
        applyVelocity(slot, deltaTime);
      }
    }
  }

  /// Iterates over all allocated slots.
  void forEach(void Function(int slot) callback) {
    for (var slot = 0; slot < _capacity; slot++) {
      if (_allocated[slot]) {
        callback(slot);
      }
    }
  }

  /// Returns a list of all allocated slot indices.
  List<int> get allocatedSlots {
    final result = <int>[];
    for (var slot = 0; slot < _capacity; slot++) {
      if (_allocated[slot]) {
        result.add(slot);
      }
    }
    return result;
  }

  /// Clears all allocations and resets the arena.
  void clear() {
    _allocated.fillRange(0, _capacity, false);
    _freeListTop = 0;
    for (var i = 0; i < _capacity; i++) {
      _freeList[i] = _capacity - 1 - i;
    }
    _allocatedCount = 0;
  }

  /// Gets direct access to the underlying data (for advanced usage).
  Float64List get rawData => _data;
}

/// A specialized arena for 2D vector data only.
class Vec2Arena {
  Vec2Arena({required int capacity})
    : _capacity = capacity,
      _xData = Float64List(capacity),
      _yData = Float64List(capacity),
      _allocated = List<bool>.filled(capacity, false),
      _freeList = List<int>.generate(capacity, (i) => capacity - 1 - i);

  final int _capacity;
  final Float64List _xData;
  final Float64List _yData;
  final List<bool> _allocated;
  final List<int> _freeList;
  int _freeListTop = 0;

  int get capacity => _capacity;

  int allocate() {
    if (_freeListTop >= _capacity) return -1;
    final slot = _freeList[_freeListTop++];
    _allocated[slot] = true;
    _xData[slot] = 0.0;
    _yData[slot] = 0.0;
    return slot;
  }

  void free(int slot) {
    if (slot < 0 || slot >= _capacity || !_allocated[slot]) return;
    _allocated[slot] = false;
    _freeList[--_freeListTop] = slot;
  }

  double getX(int slot) => _xData[slot];
  double getY(int slot) => _yData[slot];

  void set(int slot, double x, double y) {
    _xData[slot] = x;
    _yData[slot] = y;
  }

  void add(int slot, double dx, double dy) {
    _xData[slot] += dx;
    _yData[slot] += dy;
  }

  void clear() {
    _allocated.fillRange(0, _capacity, false);
    _freeListTop = 0;
    for (var i = 0; i < _capacity; i++) {
      _freeList[i] = _capacity - 1 - i;
    }
  }
}
