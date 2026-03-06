import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_signals/just_signals.dart';

void main() {
  group('AsyncSignal', () {
    test('starts in idle state', () {
      final signal = AsyncSignal<int>();
      expect(signal.state, AsyncState.idle);
      expect(signal.isLoading, false);
      expect(signal.hasData, false);
    });

    test('load transitions through states', () async {
      final signal = AsyncSignal<int>();
      final states = <AsyncState>[];

      signal.addListener(() => states.add(signal.state));

      await signal.load(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      expect(states, [AsyncState.loading, AsyncState.data]);
      expect(signal.data, 42);
    });

    test('load handles errors', () async {
      final signal = AsyncSignal<int>();

      await signal.load(() async {
        throw Exception('Test error');
      });

      expect(signal.state, AsyncState.error);
      expect(signal.hasError, true);
      expect(signal.error, isA<Exception>());
    });

    test('refresh keeps data while loading', () async {
      final signal = AsyncSignal<int>(initialData: 10);
      final states = <AsyncState>[];

      signal.addListener(() => states.add(signal.state));

      await signal.refresh(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      expect(states.contains(AsyncState.refreshing), true);
      expect(signal.data, 42);
    });

    test('setData directly sets value', () {
      final signal = AsyncSignal<int>();
      signal.setData(100);

      expect(signal.state, AsyncState.data);
      expect(signal.data, 100);
    });

    test('updateData transforms existing data', () {
      final signal = AsyncSignal<int>(initialData: 10);
      signal.updateData((v) => v * 2);

      expect(signal.data, 20);
    });
  });

  group('StreamSignal', () {
    test('receives stream events', () async {
      final controller = StreamController<int>.broadcast();
      final signal = StreamSignal(controller.stream);

      final values = <int?>[];
      signal.addListener(() => values.add(signal.data));

      controller.add(1);
      await Future.delayed(Duration.zero);
      controller.add(2);
      await Future.delayed(Duration.zero);
      controller.add(3);
      await Future.delayed(Duration.zero);

      expect(values, [1, 2, 3]);

      await controller.close();
      signal.dispose();
    });

    test('handles stream errors', () async {
      final controller = StreamController<int>.broadcast();
      final signal = StreamSignal(controller.stream);

      controller.addError(Exception('Test error'));
      await Future.delayed(Duration.zero);

      expect(signal.hasError, true);
      expect(signal.error, isA<Exception>());

      await controller.close();
      signal.dispose();
    });

    test('initialValue sets data immediately', () {
      final controller = StreamController<int>.broadcast();
      final signal = StreamSignal(controller.stream, initialValue: 42);

      expect(signal.hasData, true);
      expect(signal.data, 42);

      controller.close();
      signal.dispose();
    });
  });

  group('FutureSignal', () {
    test('executes future immediately', () async {
      final signal = FutureSignal(() async => 42);

      // Wait for completion
      await Future.delayed(Duration(milliseconds: 10));

      expect(signal.isCompleted, true);
      expect(signal.data, 42);
    });

    test('lazy signal waits for execution', () async {
      final signal = FutureSignal<int>.lazy();

      expect(signal.value.isIdle, true);

      await signal.execute(() async => 42);

      expect(signal.data, 42);
    });

    test('handles errors', () async {
      final signal = FutureSignal(() async {
        throw Exception('Test');
      });

      await Future.delayed(Duration(milliseconds: 10));

      expect(signal.hasError, true);
    });
  });

  group('StreamControllerSignal', () {
    test('add updates signal', () async {
      final signal = StreamControllerSignal<int>();

      signal.add(1);
      await Future.delayed(Duration.zero);
      expect(signal.data, 1);

      signal.add(2);
      await Future.delayed(Duration.zero);
      expect(signal.data, 2);

      signal.dispose();
    });
  });

  group('DebouncedFutureSignal', () {
    test('delays execution', () async {
      final signal = DebouncedFutureSignal<int>(
        duration: Duration(milliseconds: 50),
      );

      int execCount = 0;
      signal.schedule(() async {
        execCount++;
        return 42;
      });

      // Immediately - not executed yet
      await Future.delayed(Duration(milliseconds: 10));
      expect(execCount, 0);

      // After debounce
      await Future.delayed(Duration(milliseconds: 100));
      expect(execCount, 1);
      expect(signal.data, 42);

      signal.dispose();
    });

    test('cancel prevents execution', () async {
      final signal = DebouncedFutureSignal<int>(
        duration: Duration(milliseconds: 50),
      );

      int execCount = 0;
      signal.schedule(() async {
        execCount++;
        return 42;
      });

      signal.cancel();

      await Future.delayed(Duration(milliseconds: 100));
      expect(execCount, 0);

      signal.dispose();
    });
  });
}
