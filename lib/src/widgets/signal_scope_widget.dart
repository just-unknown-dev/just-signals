library;

import 'package:flutter/widgets.dart';

import '../core/signal.dart';
import '../core/computed.dart';
import '../core/effect.dart';
import '../core/scope.dart';

/// Provides a SignalScope to descendant widgets for automatic cleanup.
///
/// When this widget is disposed, all signals, computed values, and effects
/// created within its scope are automatically disposed.
///
/// ```dart
/// SignalScopeWidget(
///   child: MyGameUI(),
/// );
///
/// // In MyGameUI:
/// final count = Signal(0); // Auto-disposed when SignalScopeWidget unmounts
/// ```
class SignalScopeWidget extends StatefulWidget {
  const SignalScopeWidget({super.key, required this.child, this.debugLabel});

  final Widget child;
  final String? debugLabel;

  /// Gets the nearest SignalScope from the widget tree.
  static SignalScope? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SignalScopeInherited>()
        ?.scope;
  }

  /// Gets the nearest SignalScope, throwing if none found.
  static SignalScope require(BuildContext context) {
    final scope = of(context);
    if (scope == null) {
      throw FlutterError('No SignalScopeWidget found in widget tree');
    }
    return scope;
  }

  @override
  State<SignalScopeWidget> createState() => _SignalScopeWidgetState();
}

class _SignalScopeWidgetState extends State<SignalScopeWidget> {
  late SignalScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = SignalScope(debugLabel: widget.debugLabel);
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SignalScopeInherited(scope: _scope, child: widget.child);
  }
}

class _SignalScopeInherited extends InheritedWidget {
  const _SignalScopeInherited({required this.scope, required super.child});

  final SignalScope scope;

  @override
  bool updateShouldNotify(_SignalScopeInherited oldWidget) {
    return scope != oldWidget.scope;
  }
}

/// A widget that provides signals with automatic lifecycle management.
///
/// Signals created in the [create] callback are automatically disposed
/// when this widget unmounts.
///
/// ```dart
/// SignalProvider<int>(
///   create: (context) => Signal(0),
///   builder: (context, signal) => SignalBuilder(
///     signal: signal,
///     builder: (_, count, __) => Text('$count'),
///   ),
/// );
/// ```
class SignalProvider<T> extends StatefulWidget {
  const SignalProvider({
    super.key,
    required this.create,
    required this.builder,
    this.dispose,
  });

  /// Creates the signal.
  final Signal<T> Function(BuildContext context) create;

  /// Builds the child widget with access to the signal.
  final Widget Function(BuildContext context, Signal<T> signal) builder;

  /// Optional custom dispose logic.
  final void Function(Signal<T> signal)? dispose;

  @override
  State<SignalProvider<T>> createState() => _SignalProviderState<T>();
}

class _SignalProviderState<T> extends State<SignalProvider<T>> {
  late Signal<T> _signal;

  @override
  void initState() {
    super.initState();
    _signal = widget.create(context);
  }

  @override
  void dispose() {
    if (widget.dispose != null) {
      widget.dispose!(_signal);
    } else {
      _signal.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _signal);
  }
}

/// A widget that creates and provides a computed value.
class ComputedProvider<T> extends StatefulWidget {
  const ComputedProvider({
    super.key,
    required this.compute,
    required this.builder,
  });

  final T Function() compute;
  final Widget Function(BuildContext context, Computed<T> computed) builder;

  @override
  State<ComputedProvider<T>> createState() => _ComputedProviderState<T>();
}

class _ComputedProviderState<T> extends State<ComputedProvider<T>> {
  late Computed<T> _computed;

  @override
  void initState() {
    super.initState();
    _computed = Computed(widget.compute);
  }

  @override
  void dispose() {
    _computed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _computed);
  }
}

/// A widget that runs an effect and cleans it up on dispose.
class EffectWidget extends StatefulWidget {
  const EffectWidget({super.key, required this.effect, required this.child});

  final void Function()? Function() effect;
  final Widget child;

  @override
  State<EffectWidget> createState() => _EffectWidgetState();
}

class _EffectWidgetState extends State<EffectWidget> {
  late Effect _effect;

  @override
  void initState() {
    super.initState();
    _effect = Effect(widget.effect);
  }

  @override
  void dispose() {
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension for creating scoped signals in widget lifecycle.
extension SignalWidgetExtension on BuildContext {
  /// Gets the nearest SignalScope.
  SignalScope? get signalScope => SignalScopeWidget.of(this);

  /// Creates a signal in the nearest scope.
  Signal<T> createSignal<T>(T initialValue, {String? debugLabel}) {
    final scope = signalScope;
    final signal = Signal(initialValue, debugLabel: debugLabel);
    scope?.register(signal);
    return signal;
  }

  /// Creates a computed in the nearest scope.
  Computed<T> createComputed<T>(T Function() compute, {String? debugLabel}) {
    final scope = signalScope;
    final computed = Computed(compute, debugLabel: debugLabel);
    scope?.register(computed);
    return computed;
  }
}
