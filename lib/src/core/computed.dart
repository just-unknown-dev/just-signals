library;

import 'package:flutter/foundation.dart';

import 'signal.dart';

/// A computed signal that derives its value from other signals.
///
/// Computed signals are lazy - they only recompute when accessed after
/// their dependencies change. The result is cached until invalidated.
///
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// print(fullName.value); // 'John Doe'
/// firstName.value = 'Jane';
/// print(fullName.value); // 'Jane Doe'
/// ```
class Computed<T> implements ValueListenable<T> {
  /// Creates a computed signal with the given computation function.
  Computed(this._compute, {String? debugLabel})
    : _debugLabel = debugLabel ?? 'Computed<$T>' {
    _initialize();
  }

  final T Function() _compute;
  final String _debugLabel;

  T? _cachedValue;
  bool _isDirty = true;
  bool _isComputing = false;
  Set<Signal<dynamic>> _dependencies = {};
  final Set<VoidCallback> _listeners = {};

  void _initialize() {
    _recompute();
  }

  /// Recomputes the value and sets up dependency tracking.
  void _recompute() {
    if (_isComputing) {
      throw StateError('Circular dependency detected in $_debugLabel');
    }

    _isComputing = true;

    // Clean up old dependencies
    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }

    // Track new dependencies
    Signal.startTracking();
    try {
      _cachedValue = _compute();
      _isDirty = false;
    } finally {
      _dependencies = Signal.stopTracking();
      _isComputing = false;
    }

    // Subscribe to new dependencies
    for (final dep in _dependencies) {
      dep.addListener(_onDependencyChanged);
    }
  }

  void _onDependencyChanged() {
    if (!_isDirty) {
      _isDirty = true;
      _notifyListeners();
    }
  }

  /// The current computed value.
  ///
  /// The value is lazily computed and cached. It only recomputes
  /// when dependencies have changed since the last access.
  @override
  T get value {
    // Record access for nested computed signals
    if (Signal.isTracking) {
      // Register our dependencies as transitive dependencies
      for (final dep in _dependencies) {
        dep.value; // This records the access
      }
    }

    if (_isDirty) {
      _recompute();
    }
    return _cachedValue as T;
  }

  /// Forces a recomputation on next access.
  void invalidate() {
    _isDirty = true;
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List.from(_listeners)) {
      if (_listeners.contains(listener)) {
        listener();
      }
    }
  }

  /// Whether this computed has any listeners.
  bool get hasListeners => _listeners.isNotEmpty;

  /// The signals this computed depends on.
  Iterable<Signal<dynamic>> get dependencies => _dependencies;

  /// Disposes this computed and cleans up dependencies.
  void dispose() {
    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }
    _dependencies.clear();
    _listeners.clear();
  }

  @override
  String toString() => '$_debugLabel($_cachedValue)';
}

/// Creates a computed signal with the given computation.
///
/// Shorthand for `Computed(compute)`.
Computed<T> computed<T>(T Function() compute, {String? debugLabel}) =>
    Computed(compute, debugLabel: debugLabel);

/// A computed that can be written to, updating its source signals.
///
/// ```dart
/// final celsius = Signal(0.0);
/// final fahrenheit = WritableComputed(
///   read: () => celsius.value * 9/5 + 32,
///   write: (f) => celsius.value = (f - 32) * 5/9,
/// );
///
/// fahrenheit.value = 212; // Sets celsius to 100
/// ```
class WritableComputed<T> extends Computed<T> {
  WritableComputed({
    required T Function() read,
    required this.write,
    String? debugLabel,
  }) : super(read, debugLabel: debugLabel);

  /// The function to call when setting the value.
  final void Function(T value) write;

  /// Sets the computed value by calling the write function.
  set value(T newValue) {
    write(newValue);
  }
}

/// Creates a writable computed signal.
WritableComputed<T> writableComputed<T>({
  required T Function() read,
  required void Function(T value) write,
  String? debugLabel,
}) => WritableComputed(read: read, write: write, debugLabel: debugLabel);
