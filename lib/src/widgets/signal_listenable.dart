library;

import 'package:flutter/foundation.dart';

import '../core/signal.dart';

/// Adapts a Signal to Flutter's ChangeNotifier interface.
///
/// Useful for integrating signals with existing Flutter code that
/// expects ChangeNotifier.
///
/// ```dart
/// final count = Signal(0);
/// final notifier = SignalChangeNotifier(count);
///
/// AnimatedBuilder(
///   animation: notifier,
///   builder: (_, __) => Text('${count.value}'),
/// );
/// ```
class SignalChangeNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  SignalChangeNotifier(this._signal) {
    _signal.addListener(notifyListeners);
  }

  final Signal<T> _signal;

  @override
  T get value => _signal.value;

  set value(T newValue) => _signal.value = newValue;

  @override
  void dispose() {
    _signal.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Adapts a ChangeNotifier to a Signal.
///
/// ```dart
/// final notifier = ValueNotifier(0);
/// final signal = ChangeNotifierSignal(notifier, () => notifier.value);
/// ```
class ChangeNotifierSignal<T> extends Signal<T> {
  ChangeNotifierSignal(this._notifier, this._getValue, {String? debugLabel})
    : super(_getValue(), debugLabel: debugLabel) {
    _notifier.addListener(_onNotifierChanged);
  }

  final ChangeNotifier _notifier;
  final T Function() _getValue;

  void _onNotifierChanged() {
    value = _getValue();
  }

  @override
  void dispose() {
    _notifier.removeListener(_onNotifierChanged);
    super.dispose();
  }
}

/// Adapts a ValueNotifier to a Signal.
///
/// ```dart
/// final valueNotifier = ValueNotifier(0);
/// final signal = ValueNotifierSignal(valueNotifier);
///
/// signal.value = 10; // Updates the ValueNotifier too
/// ```
class ValueNotifierSignal<T> extends Signal<T> {
  ValueNotifierSignal(this._valueNotifier, {String? debugLabel})
    : super(_valueNotifier.value, debugLabel: debugLabel) {
    _valueNotifier.addListener(_onNotifierChanged);
  }

  final ValueNotifier<T> _valueNotifier;
  bool _isUpdating = false;

  void _onNotifierChanged() {
    if (_isUpdating) return;
    setSilent(_valueNotifier.value);
    dispatchNotifications();
  }

  @override
  set value(T newValue) {
    _isUpdating = true;
    try {
      _valueNotifier.value = newValue;
      super.value = newValue;
    } finally {
      _isUpdating = false;
    }
  }

  @override
  void dispose() {
    _valueNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }
}

/// Extension to convert ValueListenable to Signal.
extension ValueListenableToSignal<T> on ValueListenable<T> {
  /// Creates a signal that mirrors this ValueListenable.
  Signal<T> toSignal({String? debugLabel}) {
    if (this is Signal<T>) {
      return this as Signal<T>;
    }
    if (this is ValueNotifier<T>) {
      return ValueNotifierSignal(
        this as ValueNotifier<T>,
        debugLabel: debugLabel,
      );
    }

    // Generic ValueListenable - create read-only mirror
    final signal = Signal<T>(value, debugLabel: debugLabel);
    void listener() => signal.value = value;
    addListener(listener);
    return signal;
  }
}

/// Extension to convert Signal to ValueNotifier.
extension SignalToValueNotifier<T> on Signal<T> {
  /// Creates a ValueNotifier that mirrors this signal.
  ValueNotifier<T> toValueNotifier() {
    final notifier = ValueNotifier<T>(value);

    void onSignalChanged() {
      notifier.value = value;
    }

    addListener(onSignalChanged);
    return notifier;
  }

  /// Creates a ChangeNotifier adapter.
  SignalChangeNotifier<T> toChangeNotifier() {
    return SignalChangeNotifier(this);
  }
}

/// A signal backed by a Listenable (like Animation).
///
/// Useful for integrating with Flutter animations.
class ListenableSignal<T> extends Signal<T> {
  ListenableSignal(this._listenable, this._getValue, {String? debugLabel})
    : super(_getValue(), debugLabel: debugLabel) {
    _listenable.addListener(_onChanged);
  }

  final Listenable _listenable;
  final T Function() _getValue;

  void _onChanged() {
    value = _getValue();
  }

  @override
  void dispose() {
    _listenable.removeListener(_onChanged);
    super.dispose();
  }
}
