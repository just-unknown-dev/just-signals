library;

import 'dart:typed_data';

import 'memory_arena.dart';

/// A typed 2D vector backed by a memory arena slot.
///
/// Provides object-like access to arena data without allocations.
/// The vector reads/writes directly from the arena.
///
/// ```dart
/// final arena = MemoryArena(capacity: 100);
/// final slot = arena.allocate();
/// final position = TypedVec2(arena, slot);
///
/// position.x = 10.0;
/// position.y = 20.0;
/// position += TypedVec2.temp(5.0, 5.0); // No allocation
/// ```
class TypedVec2 {
  /// Creates a typed vector backed by an arena slot.
  TypedVec2(this._arena, this._slot, {int xOffset = 0, int yOffset = 1})
    : _xOffset = xOffset,
      _yOffset = yOffset;

  /// Creates a temporary vector for calculations (not backed by arena).
  TypedVec2.temp(double x, double y)
    : _arena = null,
      _slot = -1,
      _xOffset = 0,
      _yOffset = 1,
      _tempX = x,
      _tempY = y;

  final MemoryArena? _arena;
  final int _slot;
  final int _xOffset;
  final int _yOffset;
  double _tempX = 0.0;
  double _tempY = 0.0;

  bool get _isTemp => _arena == null;

  /// The X component.
  double get x => _isTemp ? _tempX : _arena!.getValue(_slot, _xOffset);
  set x(double value) {
    if (_isTemp) {
      _tempX = value;
    } else {
      _arena!.setValue(_slot, _xOffset, value);
    }
  }

  /// The Y component.
  double get y => _isTemp ? _tempY : _arena!.getValue(_slot, _yOffset);
  set y(double value) {
    if (_isTemp) {
      _tempY = value;
    } else {
      _arena!.setValue(_slot, _yOffset, value);
    }
  }

  /// Sets both components.
  void set(double x, double y) {
    this.x = x;
    this.y = y;
  }

  /// Adds another vector's values.
  void add(TypedVec2 other) {
    x += other.x;
    y += other.y;
  }

  /// Subtracts another vector's values.
  void subtract(TypedVec2 other) {
    x -= other.x;
    y -= other.y;
  }

  /// Scales the vector.
  void scale(double factor) {
    x *= factor;
    y *= factor;
  }

  /// The squared length of this vector.
  double get lengthSquared => x * x + y * y;

  /// The length of this vector.
  double get length {
    final ls = lengthSquared;
    if (ls == 0) return 0;
    return _sqrt(ls);
  }

  /// Normalizes this vector in place.
  void normalize() {
    final len = length;
    if (len > 0) {
      x /= len;
      y /= len;
    }
  }

  /// Dot product with another vector.
  double dot(TypedVec2 other) => x * other.x + y * other.y;

  /// Distance to another vector.
  double distanceTo(TypedVec2 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return _sqrt(dx * dx + dy * dy);
  }

  /// Distance squared to another vector (avoids sqrt).
  double distanceSquaredTo(TypedVec2 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dx * dx + dy * dy;
  }

  /// Copies values from another vector.
  void copyFrom(TypedVec2 other) {
    x = other.x;
    y = other.y;
  }

  // Fast sqrt approximation for performance
  static double _sqrt(double x) {
    // Using Dart's built-in sqrt - it's already optimized
    return x.isNaN || x < 0
        ? 0
        : x == 0
        ? 0
        : _dartSqrt(x);
  }

  static double _dartSqrt(double x) {
    // Dart's sqrt is highly optimized, use it directly
    return x <= 0
        ? 0
        : x.isInfinite
        ? x
        : _sqrtImpl(x);
  }

  static double _sqrtImpl(double x) {
    // Newton-Raphson for cases where we need more control
    // But Dart's built-in is fine for most cases
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  @override
  String toString() => 'TypedVec2($x, $y)';
}

/// A typed transform backed by a memory arena slot.
///
/// Represents position, rotation, and scale without allocations.
class TypedTransform {
  TypedTransform(this._arena, this._slot);

  final MemoryArena _arena;
  final int _slot;

  // Position
  double get x => _arena.getX(_slot);
  set x(double value) => _arena.setValue(_slot, MemoryArena.offsetX, value);

  double get y => _arena.getY(_slot);
  set y(double value) => _arena.setValue(_slot, MemoryArena.offsetY, value);

  void setPosition(double x, double y) => _arena.setPosition(_slot, x, y);
  void translate(double dx, double dy) => _arena.translate(_slot, dx, dy);

  // Rotation
  double get rotation => _arena.getRotation(_slot);
  set rotation(double value) => _arena.setRotation(_slot, value);
  void rotate(double angle) => _arena.rotate(_slot, angle);

  // Scale
  double get scaleX => _arena.getScaleX(_slot);
  double get scaleY => _arena.getScaleY(_slot);
  void setScale(double scale) => _arena.setScale(_slot, scale);
  void setScaleXY(double sx, double sy) => _arena.setScaleXY(_slot, sx, sy);

  // Velocity (for physics integration)
  double get velocityX => _arena.getVelocityX(_slot);
  double get velocityY => _arena.getVelocityY(_slot);
  void setVelocity(double vx, double vy) => _arena.setVelocity(_slot, vx, vy);
  void applyVelocity(double dt) => _arena.applyVelocity(_slot, dt);

  /// The arena slot index.
  int get slot => _slot;

  @override
  String toString() =>
      'TypedTransform(pos: ($x, $y), rot: $rotation, scale: ($scaleX, $scaleY))';
}

/// A contiguous buffer of typed values with minimal overhead.
///
/// For cases where you need a simple typed array with tracking.
class TypedBuffer<T extends num> {
  TypedBuffer.float64(int capacity)
    : _float64Data = Float64List(capacity),
      _float32Data = null,
      _int32Data = null,
      _capacity = capacity;

  TypedBuffer.float32(int capacity)
    : _float64Data = null,
      _float32Data = Float32List(capacity),
      _int32Data = null,
      _capacity = capacity;

  TypedBuffer.int32(int capacity)
    : _float64Data = null,
      _float32Data = null,
      _int32Data = Int32List(capacity),
      _capacity = capacity;

  final Float64List? _float64Data;
  final Float32List? _float32Data;
  final Int32List? _int32Data;
  final int _capacity;
  int _length = 0;

  int get capacity => _capacity;
  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isFull => _length >= _capacity;

  double getFloat(int index) {
    if (_float64Data != null) return _float64Data[index];
    if (_float32Data != null) return _float32Data[index].toDouble();
    return _int32Data![index].toDouble();
  }

  void setFloat(int index, double value) {
    if (_float64Data != null) {
      _float64Data[index] = value;
    } else if (_float32Data != null) {
      _float32Data[index] = value;
    } else {
      _int32Data![index] = value.toInt();
    }
  }

  int getInt(int index) {
    if (_int32Data != null) return _int32Data[index];
    if (_float64Data != null) return _float64Data[index].toInt();
    return _float32Data![index].toInt();
  }

  void setInt(int index, int value) {
    if (_int32Data != null) {
      _int32Data[index] = value;
    } else if (_float64Data != null) {
      _float64Data[index] = value.toDouble();
    } else {
      _float32Data![index] = value.toDouble();
    }
  }

  /// Adds a value and returns its index.
  int add(num value) {
    if (_length >= _capacity) return -1;
    final index = _length++;
    if (_float64Data != null) {
      _float64Data[index] = value.toDouble();
    } else if (_float32Data != null) {
      _float32Data[index] = value.toDouble();
    } else {
      _int32Data![index] = value.toInt();
    }
    return index;
  }

  void clear() => _length = 0;

  /// Direct access to underlying data.
  Float64List? get float64Data => _float64Data;
  Float32List? get float32Data => _float32Data;
  Int32List? get int32Data => _int32Data;
}
