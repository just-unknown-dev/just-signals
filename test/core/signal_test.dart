import 'package:flutter_test/flutter_test.dart';
import 'package:just_signals/just_signals.dart';

void main() {
  group('Signal', () {
    test('creates with initial value', () {
      final count = Signal(0);
      expect(count.value, 0);
    });

    test('updates value', () {
      final count = Signal(0);
      count.value = 5;
      expect(count.value, 5);
    });

    test('notifies listeners on change', () {
      final count = Signal(0);
      int notificationCount = 0;
      count.addListener(() => notificationCount++);

      count.value = 1;
      expect(notificationCount, 1);

      count.value = 2;
      expect(notificationCount, 2);
    });

    test('does not notify when value is same', () {
      final count = Signal(0);
      int notificationCount = 0;
      count.addListener(() => notificationCount++);

      count.value = 0; // Same value
      expect(notificationCount, 0);
    });

    test('forceSet notifies even with same value', () {
      final count = Signal(0);
      int notificationCount = 0;
      count.addListener(() => notificationCount++);

      count.forceSet(0); // Force notification
      expect(notificationCount, 1);
    });

    test('setSilent does not notify', () {
      final count = Signal(0);
      int notificationCount = 0;
      count.addListener(() => notificationCount++);

      count.setSilent(5);
      expect(count.value, 5);
      expect(notificationCount, 0);
    });

    test('update function works', () {
      final count = Signal(10);
      count.update((c) => c * 2);
      expect(count.value, 20);
    });

    test('watch returns unsubscribe function', () {
      final count = Signal(0);
      int notificationCount = 0;

      final unsubscribe = count.watch(() => notificationCount++);
      count.value = 1;
      expect(notificationCount, 1);

      unsubscribe();
      count.value = 2;
      expect(notificationCount, 1); // No longer notified
    });

    test('dispose clears listeners', () {
      final count = Signal(0);
      count.addListener(() {});
      count.addListener(() {});

      expect(count.hasListeners, true);
      count.dispose();
      expect(count.hasListeners, false);
    });

    test('signal extension creates Signal', () {
      final count = 42.signal;
      expect(count.value, 42);
      expect(count, isA<Signal<int>>());
    });
  });

  group('Computed', () {
    test('computes initial value', () {
      final count = Signal(5);
      final doubled = Computed(() => count.value * 2);
      expect(doubled.value, 10);
    });

    test('recomputes when dependency changes', () {
      final count = Signal(5);
      final doubled = Computed(() => count.value * 2);

      count.value = 10;
      expect(doubled.value, 20);
    });

    test('caches value until dependency changes', () {
      int computeCount = 0;
      final count = Signal(5);
      final doubled = Computed(() {
        computeCount++;
        return count.value * 2;
      });

      doubled.value; // First computation
      doubled.value; // Should use cache
      doubled.value; // Should use cache

      expect(computeCount, 1);

      count.value = 10; // Invalidate
      doubled.value; // Recompute

      expect(computeCount, 2);
    });

    test('tracks multiple dependencies', () {
      final a = Signal(2);
      final b = Signal(3);
      final sum = Computed(() => a.value + b.value);

      expect(sum.value, 5);

      a.value = 10;
      expect(sum.value, 13);

      b.value = 7;
      expect(sum.value, 17);
    });

    test('computed notifies its listeners', () {
      final count = Signal(5);
      final doubled = Computed(() => count.value * 2);
      int notificationCount = 0;

      doubled.addListener(() => notificationCount++);
      count.value = 10;

      expect(notificationCount, 1);
    });
  });

  group('Effect', () {
    test('runs immediately by default', () {
      bool ran = false;
      Effect(() {
        ran = true;
        return null;
      });
      expect(ran, true);
    });

    test('can defer immediate execution', () {
      bool ran = false;
      Effect(() {
        ran = true;
        return null;
      }, immediate: false);
      expect(ran, false);
    });

    test('re-runs when dependencies change', () {
      final count = Signal(0);
      List<int> values = [];

      Effect(() {
        values.add(count.value);
        return null;
      });

      count.value = 1;
      count.value = 2;

      expect(values, [0, 1, 2]);
    });

    test('runs cleanup on re-run', () {
      final count = Signal(0);
      int cleanupCount = 0;

      Effect(() {
        count.value; // Track dependency
        return () => cleanupCount++;
      });

      expect(cleanupCount, 0);

      count.value = 1;
      expect(cleanupCount, 1);

      count.value = 2;
      expect(cleanupCount, 2);
    });

    test('runs cleanup on dispose', () {
      int cleanupCount = 0;
      final e = Effect(() {
        return () => cleanupCount++;
      });

      expect(cleanupCount, 0);
      e.dispose();
      expect(cleanupCount, 1);
    });

    test('watch helper creates simple effect', () {
      final count = Signal(0);
      List<int> values = [];

      watch(() => values.add(count.value));

      count.value = 1;
      expect(values, [0, 1]);
    });

    test('on helper only fires on change', () {
      final user = Signal('John');
      List<String> names = [];

      on(() => user.value, (name) => names.add(name), fireImmediately: true);

      user.value = 'Jane';
      user.value = 'Jane'; // Same value - shouldn't fire
      user.value = 'Bob';

      expect(names, ['John', 'Jane', 'Bob']);
    });
  });

  group('Batch', () {
    test('defers notifications until batch completes', () {
      final a = Signal(0);
      final b = Signal(0);
      int notificationCount = 0;

      a.addListener(() => notificationCount++);
      b.addListener(() => notificationCount++);

      batch(() {
        a.value = 1;
        b.value = 1;
        expect(notificationCount, 0); // No notifications yet
      });

      expect(notificationCount, 2); // Both notified after batch
    });

    test('nested batches work correctly', () {
      final count = Signal(0);
      int notificationCount = 0;
      count.addListener(() => notificationCount++);

      batch(() {
        count.value = 1;
        batch(() {
          count.value = 2;
          count.value = 3;
        });
        expect(notificationCount, 0); // Still batching
      });

      expect(notificationCount, 1); // Only final value notified
    });
  });

  group('Selector', () {
    test('combine2 combines two signals', () {
      final first = Signal('John');
      final last = Signal('Doe');
      final full = combine2(first, last, (f, l) => '$f $l');

      expect(full.value, 'John Doe');

      first.value = 'Jane';
      expect(full.value, 'Jane Doe');
    });

    test('combineAll combines list of signals', () {
      final signals = [Signal(1), Signal(2), Signal(3)];
      final sum = combineAll(signals);

      expect(sum.value, [1, 2, 3]);

      signals[0].value = 10;
      expect(sum.value, [10, 2, 3]);
    });
  });
}
