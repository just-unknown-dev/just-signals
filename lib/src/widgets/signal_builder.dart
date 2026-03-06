library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/signal.dart';

/// A widget that rebuilds only when its signal changes.
///
/// SignalBuilder provides surgical rendering - when the signal value changes,
/// only this specific widget rebuilds, leaving the rest of the tree untouched.
///
/// ```dart
/// final count = Signal(0);
///
/// SignalBuilder<int>(
///   signal: count,
///   builder: (context, value, child) => Text('Count: $value'),
/// );
/// ```
class SignalBuilder<T> extends StatefulWidget {
  const SignalBuilder({
    super.key,
    required this.signal,
    required this.builder,
    this.child,
  });

  /// The signal to listen to.
  final ValueListenable<T> signal;

  /// Builder function called when the signal changes.
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// Optional child widget that doesn't depend on the signal value.
  final Widget? child;

  @override
  State<SignalBuilder<T>> createState() => _SignalBuilderState<T>();
}

class _SignalBuilderState<T> extends State<SignalBuilder<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.signal.value;
    widget.signal.addListener(_onSignalChanged);
  }

  @override
  void didUpdateWidget(SignalBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal != widget.signal) {
      oldWidget.signal.removeListener(_onSignalChanged);
      _value = widget.signal.value;
      widget.signal.addListener(_onSignalChanged);
    }
  }

  @override
  void dispose() {
    widget.signal.removeListener(_onSignalChanged);
    super.dispose();
  }

  void _onSignalChanged() {
    final newValue = widget.signal.value;
    if (_value != newValue) {
      setState(() {
        _value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value, widget.child);
  }
}

/// A widget that consumes multiple signals.
///
/// Use this when you need to react to multiple signals in a single widget.
///
/// ```dart
/// SignalConsumer(
///   signals: [firstName, lastName],
///   builder: (context) => Text('${firstName.value} ${lastName.value}'),
/// );
/// ```
class SignalConsumer extends StatefulWidget {
  const SignalConsumer({
    super.key,
    required this.signals,
    required this.builder,
    this.child,
  });

  /// The signals to listen to.
  final List<ValueListenable<dynamic>> signals;

  /// Builder function called when any signal changes.
  final Widget Function(BuildContext context, Widget? child) builder;

  /// Optional child widget that doesn't depend on signal values.
  final Widget? child;

  @override
  State<SignalConsumer> createState() => _SignalConsumerState();
}

class _SignalConsumerState extends State<SignalConsumer> {
  @override
  void initState() {
    super.initState();
    for (final signal in widget.signals) {
      signal.addListener(_onSignalChanged);
    }
  }

  @override
  void didUpdateWidget(SignalConsumer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Remove old listeners
    for (final signal in oldWidget.signals) {
      if (!widget.signals.contains(signal)) {
        signal.removeListener(_onSignalChanged);
      }
    }
    // Add new listeners
    for (final signal in widget.signals) {
      if (!oldWidget.signals.contains(signal)) {
        signal.addListener(_onSignalChanged);
      }
    }
  }

  @override
  void dispose() {
    for (final signal in widget.signals) {
      signal.removeListener(_onSignalChanged);
    }
    super.dispose();
  }

  void _onSignalChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.child);
  }
}

/// A widget that builds based on two signals.
class SignalBuilder2<A, B> extends StatefulWidget {
  const SignalBuilder2({
    super.key,
    required this.signal1,
    required this.signal2,
    required this.builder,
    this.child,
  });

  final ValueListenable<A> signal1;
  final ValueListenable<B> signal2;
  final Widget Function(BuildContext context, A value1, B value2, Widget? child)
  builder;
  final Widget? child;

  @override
  State<SignalBuilder2<A, B>> createState() => _SignalBuilder2State<A, B>();
}

class _SignalBuilder2State<A, B> extends State<SignalBuilder2<A, B>> {
  @override
  void initState() {
    super.initState();
    widget.signal1.addListener(_onChanged);
    widget.signal2.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(SignalBuilder2<A, B> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal1 != widget.signal1) {
      oldWidget.signal1.removeListener(_onChanged);
      widget.signal1.addListener(_onChanged);
    }
    if (oldWidget.signal2 != widget.signal2) {
      oldWidget.signal2.removeListener(_onChanged);
      widget.signal2.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.signal1.removeListener(_onChanged);
    widget.signal2.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      widget.signal1.value,
      widget.signal2.value,
      widget.child,
    );
  }
}

/// A widget that builds based on three signals.
class SignalBuilder3<A, B, C> extends StatefulWidget {
  const SignalBuilder3({
    super.key,
    required this.signal1,
    required this.signal2,
    required this.signal3,
    required this.builder,
    this.child,
  });

  final ValueListenable<A> signal1;
  final ValueListenable<B> signal2;
  final ValueListenable<C> signal3;
  final Widget Function(
    BuildContext context,
    A value1,
    B value2,
    C value3,
    Widget? child,
  )
  builder;
  final Widget? child;

  @override
  State<SignalBuilder3<A, B, C>> createState() =>
      _SignalBuilder3State<A, B, C>();
}

class _SignalBuilder3State<A, B, C> extends State<SignalBuilder3<A, B, C>> {
  @override
  void initState() {
    super.initState();
    widget.signal1.addListener(_onChanged);
    widget.signal2.addListener(_onChanged);
    widget.signal3.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(SignalBuilder3<A, B, C> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal1 != widget.signal1) {
      oldWidget.signal1.removeListener(_onChanged);
      widget.signal1.addListener(_onChanged);
    }
    if (oldWidget.signal2 != widget.signal2) {
      oldWidget.signal2.removeListener(_onChanged);
      widget.signal2.addListener(_onChanged);
    }
    if (oldWidget.signal3 != widget.signal3) {
      oldWidget.signal3.removeListener(_onChanged);
      widget.signal3.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.signal1.removeListener(_onChanged);
    widget.signal2.removeListener(_onChanged);
    widget.signal3.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      widget.signal1.value,
      widget.signal2.value,
      widget.signal3.value,
      widget.child,
    );
  }
}

/// A widget that selects a portion of a signal's value.
///
/// Only rebuilds when the selected portion changes.
class SignalSelector<T, R> extends StatefulWidget {
  const SignalSelector({
    super.key,
    required this.signal,
    required this.selector,
    required this.builder,
    this.equals,
    this.child,
  });

  final ValueListenable<T> signal;
  final R Function(T value) selector;
  final Widget Function(BuildContext context, R selected, Widget? child)
  builder;
  final bool Function(R previous, R current)? equals;
  final Widget? child;

  @override
  State<SignalSelector<T, R>> createState() => _SignalSelectorState<T, R>();
}

class _SignalSelectorState<T, R> extends State<SignalSelector<T, R>> {
  late R _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selector(widget.signal.value);
    widget.signal.addListener(_onSignalChanged);
  }

  @override
  void didUpdateWidget(SignalSelector<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal != widget.signal) {
      oldWidget.signal.removeListener(_onSignalChanged);
      _selectedValue = widget.selector(widget.signal.value);
      widget.signal.addListener(_onSignalChanged);
    }
  }

  @override
  void dispose() {
    widget.signal.removeListener(_onSignalChanged);
    super.dispose();
  }

  void _onSignalChanged() {
    final newSelected = widget.selector(widget.signal.value);
    final equals = widget.equals ?? (a, b) => a == b;

    if (!equals(_selectedValue, newSelected)) {
      setState(() {
        _selectedValue = newSelected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selectedValue, widget.child);
  }
}
