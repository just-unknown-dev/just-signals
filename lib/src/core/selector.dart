library;

import 'signal.dart';
import 'computed.dart';

/// A selector that derives a subset of data from a signal.
///
/// Selectors prevent unnecessary rebuilds by only notifying when
/// the selected portion of data changes, not the entire signal.
///
/// ```dart
/// final user = Signal(User(name: 'John', age: 30));
/// final name = user.select((u) => u.name);
///
/// // Only rebuilds when name changes, not age
/// SignalBuilder(signal: name, builder: (_, name, __) => Text(name));
/// ```
class Selector<T, R> extends Computed<R> {
  Selector(
    Signal<T> source,
    R Function(T value) selector, {
    this.equals,
    String? debugLabel,
  }) : super(
         () => selector(source.value),
         debugLabel: debugLabel ?? 'Selector<$T, $R>',
       );

  /// Custom equality function for comparing selected values.
  final bool Function(R previous, R current)? equals;
}

/// Extension for creating selectors from signals.
extension SignalSelectorExtension<T> on Signal<T> {
  /// Creates a selector that derives a value from this signal.
  ///
  /// The selector only notifies when the derived value changes.
  Computed<R> select<R>(R Function(T value) selector, {String? debugLabel}) {
    return Computed(() => selector(value), debugLabel: debugLabel);
  }

  /// Creates multiple selectors at once.
  List<Computed<dynamic>> selectMany(
    List<dynamic Function(T value)> selectors,
  ) {
    return selectors
        .map((selector) => Computed(() => selector(value)))
        .toList();
  }
}

/// A multi-signal selector that combines values from multiple signals.
///
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
///
/// final fullName = combine2(
///   firstName,
///   lastName,
///   (first, last) => '$first $last',
/// );
/// ```
Computed<R> combine2<A, B, R>(
  Signal<A> a,
  Signal<B> b,
  R Function(A a, B b) combiner, {
  String? debugLabel,
}) {
  return Computed(
    () => combiner(a.value, b.value),
    debugLabel: debugLabel ?? 'Combine2<$R>',
  );
}

/// Combines three signals.
Computed<R> combine3<A, B, C, R>(
  Signal<A> a,
  Signal<B> b,
  Signal<C> c,
  R Function(A a, B b, C c) combiner, {
  String? debugLabel,
}) {
  return Computed(
    () => combiner(a.value, b.value, c.value),
    debugLabel: debugLabel ?? 'Combine3<$R>',
  );
}

/// Combines four signals.
Computed<R> combine4<A, B, C, D, R>(
  Signal<A> a,
  Signal<B> b,
  Signal<C> c,
  Signal<D> d,
  R Function(A a, B b, C c, D d) combiner, {
  String? debugLabel,
}) {
  return Computed(
    () => combiner(a.value, b.value, c.value, d.value),
    debugLabel: debugLabel ?? 'Combine4<$R>',
  );
}

/// Combines a list of signals of the same type.
Computed<List<T>> combineAll<T>(List<Signal<T>> signals, {String? debugLabel}) {
  return Computed(
    () => signals.map((s) => s.value).toList(),
    debugLabel: debugLabel ?? 'CombineAll<$T>',
  );
}

/// Creates a computed that filters a list signal.
Computed<List<T>> where<T>(
  Signal<List<T>> source,
  bool Function(T item) predicate, {
  String? debugLabel,
}) {
  return Computed(
    () => source.value.where(predicate).toList(),
    debugLabel: debugLabel ?? 'Where<$T>',
  );
}

/// Creates a computed that maps a list signal.
Computed<List<R>> map<T, R>(
  Signal<List<T>> source,
  R Function(T item) mapper, {
  String? debugLabel,
}) {
  return Computed(
    () => source.value.map(mapper).toList(),
    debugLabel: debugLabel ?? 'Map<$T, $R>',
  );
}
