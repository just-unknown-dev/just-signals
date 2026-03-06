library;

import 'dart:async';

import '../core/signal.dart';
import 'async_signal.dart';

/// A signal that wraps a Future for one-shot async operations.
///
/// Unlike AsyncSignal, FutureSignal is initialized with a future immediately
/// and is intended for operations that complete once.
///
/// ```dart
/// final config = FutureSignal(() => loadConfig());
///
/// SignalBuilder(
///   signal: config,
///   builder: (_, snapshot, __) {
///     if (snapshot.isLoading) return CircularProgressIndicator();
///     if (snapshot.hasError) return Text('Error');
///     return Text('Loaded: ${snapshot.data}');
///   },
/// );
/// ```
class FutureSignal<T> extends Signal<AsyncSnapshot<T>> {
  /// Creates a future signal that immediately starts the operation.
  FutureSignal(Future<T> Function() futureBuilder, {String? debugLabel})
    : super(
        AsyncSnapshot<T>.loading(),
        debugLabel: debugLabel ?? 'FutureSignal<$T>',
      ) {
    _execute(futureBuilder);
  }

  /// Creates a future signal from an existing future.
  FutureSignal.from(Future<T> future, {String? debugLabel})
    : super(
        AsyncSnapshot<T>.loading(),
        debugLabel: debugLabel ?? 'FutureSignal<$T>',
      ) {
    _execute(() => future);
  }

  /// Creates a future signal that waits for manual triggering.
  FutureSignal.lazy({String? debugLabel})
    : super(
        AsyncSnapshot<T>.idle(),
        debugLabel: debugLabel ?? 'FutureSignal<$T>',
      );

  bool _isCompleted = false;
  bool _isCancelled = false;

  /// Whether the future has completed.
  bool get isCompleted => _isCompleted;

  /// Whether the operation was cancelled.
  bool get isCancelled => _isCancelled;

  /// The current data.
  T? get data => value.data;

  /// Whether has data.
  bool get hasData => value.hasData;

  /// Whether has error.
  bool get hasError => value.hasError;

  /// Whether is loading.
  bool get isLoading => value.isLoading;

  Future<void> _execute(Future<T> Function() futureBuilder) async {
    value = AsyncSnapshot<T>.loading();

    try {
      final result = await futureBuilder();
      if (_isCancelled) return;

      _isCompleted = true;
      value = AsyncSnapshot.withData(result);
    } catch (e, st) {
      if (_isCancelled) return;

      _isCompleted = true;
      value = AsyncSnapshot.withError(e, st);
    }
  }

  /// Executes the future (for lazy signals).
  Future<void> execute(Future<T> Function() futureBuilder) {
    if (_isCompleted) {
      throw StateError('FutureSignal has already completed');
    }
    return _execute(futureBuilder);
  }

  /// Cancels the operation (prevents updating signal after completion).
  void cancel() {
    _isCancelled = true;
  }

  /// Resets the signal to idle state (for lazy signals).
  void reset() {
    _isCompleted = false;
    _isCancelled = false;
    value = AsyncSnapshot<T>.idle();
  }
}

/// A signal that handles a list of futures.
class FutureListSignal<T> extends Signal<AsyncSnapshot<List<T>>> {
  FutureListSignal(
    List<Future<T>> futures, {
    bool parallel = true,
    String? debugLabel,
  }) : super(
         AsyncSnapshot<List<T>>.loading(),
         debugLabel: debugLabel ?? 'FutureListSignal<$T>',
       ) {
    if (parallel) {
      _executeParallel(futures);
    } else {
      _executeSequential(futures);
    }
  }

  Future<void> _executeParallel(List<Future<T>> futures) async {
    try {
      final results = await Future.wait(futures);
      value = AsyncSnapshot.withData(results);
    } catch (e, st) {
      value = AsyncSnapshot.withError(e, st);
    }
  }

  Future<void> _executeSequential(List<Future<T>> futures) async {
    final results = <T>[];
    try {
      for (final future in futures) {
        results.add(await future);
      }
      value = AsyncSnapshot.withData(results);
    } catch (e, st) {
      value = AsyncSnapshot.withError(e, st);
    }
  }

  List<T>? get data => value.data;
  bool get hasData => value.hasData;
}

/// A debounced future signal that delays execution.
///
/// Useful for search inputs where you want to wait for the user to stop typing.
class DebouncedFutureSignal<T> extends Signal<AsyncSnapshot<T>> {
  DebouncedFutureSignal({required this.duration, String? debugLabel})
    : super(
        AsyncSnapshot<T>.idle(),
        debugLabel: debugLabel ?? 'DebouncedFutureSignal<$T>',
      );

  final Duration duration;
  Timer? _debounceTimer;

  /// Schedules a future to execute after the debounce duration.
  void schedule(Future<T> Function() futureBuilder) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () => _execute(futureBuilder));
  }

  /// Immediately executes without waiting for debounce.
  void executeNow(Future<T> Function() futureBuilder) {
    _debounceTimer?.cancel();
    _execute(futureBuilder);
  }

  Future<void> _execute(Future<T> Function() futureBuilder) async {
    value = AsyncSnapshot<T>.loading();
    try {
      final result = await futureBuilder();
      value = AsyncSnapshot.withData(result);
    } catch (e, st) {
      value = AsyncSnapshot.withError(e, st);
    }
  }

  /// Cancels any pending execution.
  void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  T? get data => value.data;
  bool get hasData => value.hasData;
  bool get isLoading => value.isLoading;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Creates a future signal.
FutureSignal<T> futureSignal<T>(
  Future<T> Function() futureBuilder, {
  String? debugLabel,
}) => FutureSignal(futureBuilder, debugLabel: debugLabel);
