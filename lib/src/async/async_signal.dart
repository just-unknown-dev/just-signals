library;

import 'dart:async';

import '../core/signal.dart';

/// Represents the state of an async operation.
enum AsyncState {
  /// Initial state, not yet started.
  idle,

  /// Currently loading.
  loading,

  /// Successfully completed with data.
  data,

  /// Failed with an error.
  error,

  /// Operation was refreshing (has data but also loading).
  refreshing,
}

/// A signal that handles asynchronous operations.
///
/// AsyncSignal manages loading, error, and data states automatically,
/// eliminating the need for complex FutureBuilder nesting.
///
/// ```dart
/// final userSignal = AsyncSignal<User>();
///
/// // Load data
/// await userSignal.load(() => api.fetchUser(userId));
///
/// // Use in widget
/// SignalBuilder(
///   signal: userSignal,
///   builder: (_, snapshot, __) {
///     if (snapshot.isLoading) return CircularProgressIndicator();
///     if (snapshot.hasError) return Text('Error: ${snapshot.error}');
///     return Text('Hello ${snapshot.data!.name}');
///   },
/// );
/// ```
class AsyncSignal<T> extends Signal<AsyncSnapshot<T>> {
  AsyncSignal({T? initialData, String? debugLabel})
    : super(
        initialData != null
            ? AsyncSnapshot.withData(initialData)
            : AsyncSnapshot<T>.idle(),
        debugLabel: debugLabel ?? 'AsyncSignal<$T>',
      );

  bool _isCancelled = false;

  /// The current state.
  AsyncState get state => value.state;

  /// Whether currently loading.
  bool get isLoading => value.isLoading;

  /// Whether currently refreshing (loading with existing data).
  bool get isRefreshing => value.state == AsyncState.refreshing;

  /// Whether has data.
  bool get hasData => value.hasData;

  /// Whether has an error.
  bool get hasError => value.hasError;

  /// The current data (null if not loaded).
  T? get data => value.data;

  /// The current error (null if no error).
  Object? get error => value.error;

  /// Loads data from an async function.
  ///
  /// If [refresh] is true and we have data, enters refreshing state
  /// instead of loading state.
  Future<T?> load(Future<T> Function() loader, {bool refresh = false}) async {
    _isCancelled = false;

    // Set loading or refreshing state
    if (refresh && hasData) {
      value = value.copyWithState(AsyncState.refreshing);
    } else {
      value = AsyncSnapshot<T>.loading();
    }

    try {
      final operation = loader();

      final result = await operation;

      // Check if cancelled during operation
      if (_isCancelled) return null;

      value = AsyncSnapshot.withData(result);
      return result;
    } catch (e, stackTrace) {
      if (_isCancelled) return null;

      value = AsyncSnapshot.withError(e, stackTrace);
      return null;
    }
  }

  /// Refreshes the data (loads while keeping existing data visible).
  Future<T?> refresh(Future<T> Function() loader) {
    return load(loader, refresh: true);
  }

  /// Cancels the current operation.
  void cancel() {
    _isCancelled = true;
  }

  /// Sets the data directly.
  void setData(T newData) {
    value = AsyncSnapshot.withData(newData);
  }

  /// Sets an error directly.
  void setError(Object error, [StackTrace? stackTrace]) {
    value = AsyncSnapshot.withError(error, stackTrace);
  }

  /// Resets to idle state.
  void reset() {
    cancel();
    value = AsyncSnapshot<T>.idle();
  }

  /// Updates the data if present.
  void updateData(T Function(T current) updater) {
    if (hasData) {
      value = AsyncSnapshot.withData(updater(data as T));
    }
  }
}

/// A snapshot of an async operation's state.
class AsyncSnapshot<T> {
  const AsyncSnapshot._({
    required this.state,
    this.data,
    this.error,
    this.stackTrace,
  });

  /// Initial idle state.
  factory AsyncSnapshot.idle() => AsyncSnapshot._(state: AsyncState.idle);

  /// Loading state.
  factory AsyncSnapshot.loading() => AsyncSnapshot._(state: AsyncState.loading);

  /// Data state.
  factory AsyncSnapshot.withData(T data) =>
      AsyncSnapshot._(state: AsyncState.data, data: data);

  /// Error state.
  factory AsyncSnapshot.withError(Object error, [StackTrace? stackTrace]) =>
      AsyncSnapshot._(
        state: AsyncState.error,
        error: error,
        stackTrace: stackTrace,
      );

  final AsyncState state;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isIdle => state == AsyncState.idle;
  bool get isLoading =>
      state == AsyncState.loading || state == AsyncState.refreshing;
  bool get hasData => data != null;
  bool get hasError => error != null;

  /// Gets data or throws if not available.
  T get requireData {
    if (data == null) {
      throw StateError('No data available');
    }
    return data as T;
  }

  /// Returns a copy with a different state.
  AsyncSnapshot<T> copyWithState(AsyncState newState) {
    return AsyncSnapshot._(
      state: newState,
      data: data,
      error: newState == AsyncState.data || newState == AsyncState.refreshing
          ? error
          : null,
      stackTrace: stackTrace,
    );
  }

  /// Maps the data to a different type.
  AsyncSnapshot<R> map<R>(R Function(T data) mapper) {
    if (hasData) {
      return AsyncSnapshot._(
        state: state,
        data: mapper(data as T),
        error: error,
        stackTrace: stackTrace,
      );
    }
    return AsyncSnapshot._(state: state, error: error, stackTrace: stackTrace);
  }

  @override
  String toString() => 'AsyncSnapshot($state, data: $data, error: $error)';
}

/// Creates an async signal with optional initial data.
AsyncSignal<T> asyncSignal<T>({T? initialData, String? debugLabel}) =>
    AsyncSignal(initialData: initialData, debugLabel: debugLabel);
