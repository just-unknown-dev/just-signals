library;

import 'package:flutter/foundation.dart';

import 'batch.dart';
import 'scope.dart';

/// A reactive primitive that holds a value and notifies listeners when it changes.
///
/// Signals are the foundation of the reactive system. They provide surgical
/// precision updates - only the specific widgets/effects that depend on a
/// signal will rebuild when it changes.
///
/// ```dart
/// final count = Signal(0);
/// count.value++; // Notifies all listeners
/// ```
class Signal<T> implements ValueListenable<T> {
  /// Creates a signal with an initial value.
  Signal(this._value, {String? debugLabel})
    : _debugLabel = debugLabel ?? 'Signal<$T>';

  T _value;
  final String _debugLabel;
  final Set<VoidCallback> _listeners = {};

  /// Stack of tracking contexts for nested computed/effects.
  static final List<Set<Signal<dynamic>>> _trackingStack = [];

  /// Whether we're currently tracking dependencies.
  static bool get isTracking => _trackingStack.isNotEmpty;

  /// Starts tracking signal accesses for dependency detection.
  static void startTracking() {
    _trackingStack.add(<Signal<dynamic>>{});
  }

  /// Stops tracking and returns the accessed signals.
  static Set<Signal<dynamic>> stopTracking() {
    if (_trackingStack.isEmpty) {
      return <Signal<dynamic>>{};
    }
    return _trackingStack.removeLast();
  }

  /// Records this signal as accessed during tracking.
  void _recordAccess() {
    if (_trackingStack.isNotEmpty) {
      _trackingStack.last.add(this);
    }
  }

  /// The current value of the signal.
  ///
  /// Reading this value will register the signal as a dependency
  /// if called within a tracking context (Computed or Effect).
  @override
  T get value {
    _recordAccess();
    return _value;
  }

  /// Sets the value and notifies listeners if it changed.
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      _notifyListeners();
    }
  }

  /// Updates the value using a function.
  ///
  /// Useful for complex updates that depend on the previous value.
  void update(T Function(T current) updater) {
    value = updater(_value);
  }

  /// Sets the value without checking for equality.
  ///
  /// Forces notification even if the value is the same.
  void forceSet(T newValue) {
    _value = newValue;
    _notifyListeners();
  }

  /// Silently sets the value without notifying listeners.
  ///
  /// Use with caution - this can cause state inconsistencies.
  void setSilent(T newValue) {
    _value = newValue;
  }

  /// Notifies all listeners of a change.
  void _notifyListeners() {
    if (SignalBatch.isBatching) {
      SignalBatch.scheduledSignals.add(this);
      return;
    }
    dispatchNotifications();
  }

  /// Actually dispatches notifications to listeners.
  ///
  /// This is called internally by the batching system. Avoid calling directly.
  void dispatchNotifications() {
    // Create a copy to allow modifications during iteration
    final listeners = List<VoidCallback>.from(_listeners);
    for (final listener in listeners) {
      if (_listeners.contains(listener)) {
        listener();
      }
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Whether this signal has any listeners.
  bool get hasListeners => _listeners.isNotEmpty;

  /// The number of current listeners.
  int get listenerCount => _listeners.length;

  /// Disposes this signal and removes all listeners.
  void dispose() {
    _listeners.clear();
    SignalScope.current?.unregister(this);
  }

  /// Watches this signal and returns an unsubscribe function.
  ///
  /// ```dart
  /// final unsubscribe = count.watch(() => print('Changed!'));
  /// // Later...
  /// unsubscribe();
  /// ```
  VoidCallback watch(VoidCallback callback) {
    addListener(callback);
    return () => removeListener(callback);
  }

  @override
  String toString() => '$_debugLabel($_value)';
}

/// Extension for creating signals from values.
extension SignalExtension<T> on T {
  /// Creates a signal with this value.
  Signal<T> get signal => Signal(this);
}

/// A signal that can be null.
typedef NullableSignal<T> = Signal<T?>;

/// Creates a signal with the given initial value.
///
/// Shorthand for `Signal(value)`.
Signal<T> signal<T>(T value, {String? debugLabel}) =>
    Signal(value, debugLabel: debugLabel);
