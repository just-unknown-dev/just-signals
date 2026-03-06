library;

import 'dart:async';

import '../core/signal.dart';
import 'async_signal.dart';

/// A signal that wraps a Stream.
///
/// StreamSignal manages stream subscriptions automatically and provides
/// reactive access to stream data.
///
/// ```dart
/// final messages = StreamSignal<Message>(
///   messageStream,
///   initialValue: null,
/// );
///
/// SignalBuilder(
///   signal: messages,
///   builder: (_, snapshot, __) {
///     if (!snapshot.hasData) return Text('No messages');
///     return Text(snapshot.data!.content);
///   },
/// );
/// ```
class StreamSignal<T> extends Signal<AsyncSnapshot<T>> {
  /// Creates a stream signal.
  ///
  /// If [initialValue] is provided, the signal starts with data.
  /// Otherwise, it starts in loading state.
  StreamSignal(
    Stream<T> stream, {
    T? initialValue,
    bool cancelOnDispose = true,
    String? debugLabel,
  }) : _cancelOnDispose = cancelOnDispose,
       super(
         initialValue != null
             ? AsyncSnapshot.withData(initialValue)
             : AsyncSnapshot<T>.loading(),
         debugLabel: debugLabel ?? 'StreamSignal<$T>',
       ) {
    _subscribe(stream);
  }

  final bool _cancelOnDispose;
  StreamSubscription<T>? _subscription;

  /// Whether the stream is currently active.
  bool get isActive => _subscription != null;

  /// The current data value.
  T? get data => value.data;

  /// Whether has data.
  bool get hasData => value.hasData;

  /// Whether has error.
  bool get hasError => value.hasError;

  /// The current error.
  Object? get error => value.error;

  void _subscribe(Stream<T> stream) {
    _subscription = stream.listen(
      (data) {
        value = AsyncSnapshot.withData(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        value = AsyncSnapshot.withError(error, stackTrace);
      },
      onDone: () {
        // Keep last value when stream completes
      },
    );
  }

  /// Re-subscribes to a new stream.
  void switchStream(Stream<T> newStream) {
    _subscription?.cancel();
    value = AsyncSnapshot<T>.loading();
    _subscribe(newStream);
  }

  /// Pauses the stream subscription.
  void pause() {
    _subscription?.pause();
  }

  /// Resumes the stream subscription.
  void resume() {
    _subscription?.resume();
  }

  @override
  void dispose() {
    if (_cancelOnDispose) {
      _subscription?.cancel();
    }
    _subscription = null;
    super.dispose();
  }
}

/// A signal that wraps a broadcast stream and allows late subscribers.
class BroadcastStreamSignal<T> extends StreamSignal<T> {
  BroadcastStreamSignal(
    Stream<T> stream, {
    super.initialValue,
    super.cancelOnDispose,
    super.debugLabel,
  }) : super(stream.isBroadcast ? stream : stream.asBroadcastStream());
}

/// A signal that emits values from a StreamController.
///
/// Useful when you want to create a stream signal that you control.
class StreamControllerSignal<T> extends Signal<AsyncSnapshot<T>> {
  StreamControllerSignal({
    T? initialValue,
    bool sync = false,
    String? debugLabel,
  }) : _controller = sync
           ? StreamController<T>.broadcast(sync: true)
           : StreamController<T>.broadcast(),
       super(
         initialValue != null
             ? AsyncSnapshot.withData(initialValue)
             : AsyncSnapshot<T>.idle(),
         debugLabel: debugLabel ?? 'StreamControllerSignal<$T>',
       ) {
    _controller.stream.listen(
      (data) => value = AsyncSnapshot.withData(data),
      onError: (Object error, StackTrace st) =>
          value = AsyncSnapshot.withError(error, st),
    );
  }

  final StreamController<T> _controller;

  /// The underlying stream.
  Stream<T> get stream => _controller.stream;

  /// Adds a value to the stream.
  void add(T data) {
    _controller.add(data);
  }

  /// Adds an error to the stream.
  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  /// The current data value.
  T? get data => value.data;

  /// Whether has data.
  bool get hasData => value.hasData;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

/// Creates a stream signal from a stream.
StreamSignal<T> streamSignal<T>(
  Stream<T> stream, {
  T? initialValue,
  String? debugLabel,
}) => StreamSignal(stream, initialValue: initialValue, debugLabel: debugLabel);
