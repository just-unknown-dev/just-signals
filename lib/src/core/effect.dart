library;

import 'signal.dart';
import 'scope.dart';

/// A side effect that runs when its tracked signals change.
///
/// Effects automatically track which signals they access and re-run
/// when any of those signals change. They support cleanup functions
/// for disposing resources.
///
/// ```dart
/// final count = Signal(0);
///
/// final effect = Effect(() {
///   print('Count is: ${count.value}');
///   return () => print('Cleaning up');
/// });
///
/// count.value = 1; // Prints 'Cleaning up' then 'Count is: 1'
/// effect.dispose(); // Prints 'Cleaning up'
/// ```
class Effect {
  /// Creates an effect with the given side effect function.
  ///
  /// The effect runs immediately and then re-runs when dependencies change.
  /// The function can optionally return a cleanup function.
  Effect(this._effect, {String? debugLabel, bool immediate = true})
    : _debugLabel = debugLabel ?? 'Effect' {
    SignalScope.current?.register(this);
    if (immediate) {
      _run();
    }
  }

  final void Function()? Function() _effect;
  final String _debugLabel;

  void Function()? _cleanup;
  Set<Signal<dynamic>> _dependencies = {};
  bool _isDisposed = false;
  bool _isRunning = false;

  /// Runs the effect and tracks dependencies.
  void _run() {
    if (_isDisposed || _isRunning) return;

    _isRunning = true;

    // Run cleanup from previous execution
    _runCleanup();

    // Clean up old dependencies
    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }

    // Track new dependencies
    Signal.startTracking();
    try {
      _cleanup = _effect();
    } finally {
      _dependencies = Signal.stopTracking();
      _isRunning = false;
    }

    // Subscribe to new dependencies
    for (final dep in _dependencies) {
      dep.addListener(_onDependencyChanged);
    }
  }

  void _onDependencyChanged() {
    if (!_isDisposed) {
      _run();
    }
  }

  void _runCleanup() {
    if (_cleanup != null) {
      try {
        _cleanup!();
      } catch (e) {
        // Ignore cleanup errors but could log in debug mode
      }
      _cleanup = null;
    }
  }

  /// Manually triggers the effect to re-run.
  void trigger() {
    _run();
  }

  /// Pauses the effect from responding to changes.
  void pause() {
    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }
  }

  /// Resumes the effect after being paused.
  void resume() {
    for (final dep in _dependencies) {
      dep.addListener(_onDependencyChanged);
    }
  }

  /// Disposes this effect and runs cleanup.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _runCleanup();

    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }
    _dependencies.clear();

    SignalScope.current?.unregister(this);
  }

  /// Whether this effect has been disposed.
  bool get isDisposed => _isDisposed;

  /// The signals this effect depends on.
  Iterable<Signal<dynamic>> get dependencies => _dependencies;

  @override
  String toString() => '$_debugLabel(deps: ${_dependencies.length})';
}

/// Creates an effect that runs the given function.
///
/// Shorthand for `Effect(effect)`.
Effect effect(
  void Function()? Function() fn, {
  String? debugLabel,
  bool immediate = true,
}) => Effect(fn, debugLabel: debugLabel, immediate: immediate);

/// Creates an effect from a simple void function (no cleanup).
///
/// ```dart
/// watch(() => print('Count: ${count.value}'));
/// ```
Effect watch(void Function() fn, {String? debugLabel}) => Effect(() {
  fn();
  return null;
}, debugLabel: debugLabel);

/// Creates a one-time effect that disposes itself after running.
///
/// Useful for reactions that should only happen once.
Effect once(void Function() fn, {String? debugLabel}) {
  late Effect e;
  e = Effect(() {
    fn();
    e.dispose();
    return null;
  }, debugLabel: debugLabel);
  return e;
}

/// Creates an effect that only runs when the selector value changes.
///
/// ```dart
/// on(
///   () => user.value.name,
///   (name) => print('Name changed to: $name'),
/// );
/// ```
Effect on<T>(
  T Function() selector,
  void Function(T value) callback, {
  String? debugLabel,
  bool fireImmediately = true,
}) {
  T? previousValue;
  bool isFirst = true;

  return Effect(() {
    final currentValue = selector();

    if (isFirst) {
      isFirst = false;
      previousValue = currentValue;
      if (fireImmediately) {
        callback(currentValue);
      }
    } else if (currentValue != previousValue) {
      previousValue = currentValue;
      callback(currentValue);
    }

    return null;
  }, debugLabel: debugLabel);
}
