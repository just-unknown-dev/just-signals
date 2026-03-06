library;

import 'signal.dart';
import 'computed.dart';
import 'effect.dart';

/// A scope for managing signal lifecycle and automatic cleanup.
///
/// SignalScope provides hierarchical disposal - when a scope is disposed,
/// all signals, computed values, and effects created within it are also disposed.
///
/// ```dart
/// final scope = SignalScope();
/// SignalScope.runInScope(scope, () {
///   final count = Signal(0); // Registered with scope
///   final doubled = Computed(() => count.value * 2); // Registered with scope
/// });
/// scope.dispose(); // Disposes count and doubled
/// ```
class SignalScope {
  SignalScope({this.parent, String? debugLabel})
    : _debugLabel = debugLabel ?? 'SignalScope';

  /// The parent scope, if any.
  final SignalScope? parent;
  final String _debugLabel;

  final Set<Signal<dynamic>> _signals = {};
  final Set<Computed<dynamic>> _computeds = {};
  final Set<Effect> _effects = {};
  final Set<SignalScope> _children = {};

  bool _isDisposed = false;

  /// The current active scope for automatic registration.
  static SignalScope? _current;

  /// Gets the current active scope.
  static SignalScope? get current => _current;

  /// Runs a function within this scope.
  ///
  /// All signals, computeds, and effects created during execution
  /// will be registered with this scope.
  T run<T>(T Function() fn) {
    final previous = _current;
    _current = this;
    try {
      return fn();
    } finally {
      _current = previous;
    }
  }

  /// Static helper to run a function in a scope.
  static T runInScope<T>(SignalScope scope, T Function() fn) {
    return scope.run(fn);
  }

  /// Creates a child scope.
  SignalScope createChild({String? debugLabel}) {
    final child = SignalScope(parent: this, debugLabel: debugLabel);
    _children.add(child);
    return child;
  }

  /// Registers a signal with this scope.
  void register(Object item) {
    if (_isDisposed) {
      throw StateError('Cannot register to disposed scope');
    }

    if (item is Signal) {
      _signals.add(item);
    } else if (item is Computed) {
      _computeds.add(item);
    } else if (item is Effect) {
      _effects.add(item);
    }
  }

  /// Unregisters an item from this scope.
  void unregister(Object item) {
    if (item is Signal) {
      _signals.remove(item);
    } else if (item is Computed) {
      _computeds.remove(item);
    } else if (item is Effect) {
      _effects.remove(item);
    }
  }

  /// Disposes all items in this scope and child scopes.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Dispose children first
    for (final child in _children) {
      child.dispose();
    }
    _children.clear();

    // Dispose effects first (they might reference signals/computeds)
    for (final effect in _effects) {
      effect.dispose();
    }
    _effects.clear();

    // Then computeds
    for (final computed in _computeds) {
      computed.dispose();
    }
    _computeds.clear();

    // Finally signals
    for (final signal in _signals) {
      signal.dispose();
    }
    _signals.clear();

    // Remove from parent
    parent?._children.remove(this);
  }

  /// Whether this scope has been disposed.
  bool get isDisposed => _isDisposed;

  /// The number of items registered in this scope.
  int get itemCount => _signals.length + _computeds.length + _effects.length;

  @override
  String toString() =>
      '$_debugLabel(signals: ${_signals.length}, computed: ${_computeds.length}, effects: ${_effects.length})';
}

/// Creates and runs code within a new scope, returning the scope.
///
/// ```dart
/// final scope = scoped(() {
///   final count = Signal(0);
///   // ... use count
/// });
/// // Later...
/// scope.dispose();
/// ```
SignalScope scoped(void Function() fn, {String? debugLabel}) {
  final scope = SignalScope(debugLabel: debugLabel);
  scope.run(fn);
  return scope;
}
