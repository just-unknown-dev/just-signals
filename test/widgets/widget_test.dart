import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_signals/just_signals.dart';

void main() {
  group('SignalBuilder', () {
    testWidgets('rebuilds on signal change', (tester) async {
      final count = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: SignalBuilder<int>(
            signal: count,
            builder: (_, value, _) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      count.value = 5;
      await tester.pump();

      expect(find.text('Count: 5'), findsOneWidget);
    });

    testWidgets('preserves child widget', (tester) async {
      final count = Signal(0);
      int childBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SignalBuilder<int>(
            signal: count,
            child: Builder(
              builder: (_) {
                childBuilds++;
                return const Text('Child');
              },
            ),
            builder: (_, value, child) =>
                Column(children: [Text('Count: $value'), child!]),
          ),
        ),
      );

      expect(childBuilds, 1);

      count.value = 5;
      await tester.pump();

      // Child should not rebuild
      expect(childBuilds, 1);
    });

    testWidgets('updates when signal changes', (tester) async {
      final signal1 = Signal(0);
      final signal2 = Signal(100);

      late Signal<int> currentSignal;
      currentSignal = signal1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => SignalBuilder<int>(
              signal: currentSignal,
              builder: (_, value, _) => TextButton(
                onPressed: () => setState(() => currentSignal = signal2),
                child: Text('Value: $value'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);

      // Tap to switch signal
      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(find.text('Value: 100'), findsOneWidget);
    });
  });

  group('SignalConsumer', () {
    testWidgets('rebuilds on any signal change', (tester) async {
      final a = Signal(1);
      final b = Signal(2);

      await tester.pumpWidget(
        MaterialApp(
          home: SignalConsumer(
            signals: [a, b],
            builder: (_, _) => Text('Sum: ${a.value + b.value}'),
          ),
        ),
      );

      expect(find.text('Sum: 3'), findsOneWidget);

      a.value = 10;
      await tester.pump();

      expect(find.text('Sum: 12'), findsOneWidget);

      b.value = 20;
      await tester.pump();

      expect(find.text('Sum: 30'), findsOneWidget);
    });
  });

  group('SignalBuilder2', () {
    testWidgets('builds with two signals', (tester) async {
      final first = Signal('John');
      final last = Signal('Doe');

      await tester.pumpWidget(
        MaterialApp(
          home: SignalBuilder2<String, String>(
            signal1: first,
            signal2: last,
            builder: (_, f, l, _) => Text('$f $l'),
          ),
        ),
      );

      expect(find.text('John Doe'), findsOneWidget);

      first.value = 'Jane';
      await tester.pump();

      expect(find.text('Jane Doe'), findsOneWidget);
    });
  });

  group('SignalSelector', () {
    testWidgets('only rebuilds when selected value changes', (tester) async {
      final user = Signal(const User('John', 30));
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SignalSelector<User, String>(
            signal: user,
            selector: (u) => u.name,
            builder: (_, name, _) {
              buildCount++;
              return Text('Name: $name');
            },
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Name: John'), findsOneWidget);

      // Change age only - should not rebuild
      user.value = const User('John', 31);
      await tester.pump();
      expect(buildCount, 1);

      // Change name - should rebuild
      user.value = const User('Jane', 31);
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Name: Jane'), findsOneWidget);
    });
  });

  group('SignalScopeWidget', () {
    testWidgets('disposes signals when unmounted', (tester) async {
      late SignalScope scope;

      await tester.pumpWidget(
        MaterialApp(
          home: SignalScopeWidget(
            child: Builder(
              builder: (context) {
                scope = SignalScopeWidget.require(context);
                return const Text('Test');
              },
            ),
          ),
        ),
      );

      expect(scope.isDisposed, false);

      // Replace with empty widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(scope.isDisposed, true);
    });
  });

  group('SignalProvider', () {
    testWidgets('provides and disposes signal', (tester) async {
      late Signal<int> providedSignal;
      bool disposed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SignalProvider<int>(
            create: (_) => Signal(0),
            dispose: (signal) => disposed = true,
            builder: (_, signal) {
              providedSignal = signal;
              return SignalBuilder<int>(
                signal: signal,
                builder: (_, value, _) => Text('$value'),
              );
            },
          ),
        ),
      );

      expect(providedSignal.value, 0);

      providedSignal.value = 10;
      await tester.pump();

      expect(find.text('10'), findsOneWidget);

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(disposed, true);
    });
  });
}

class User {
  const User(this.name, this.age);
  final String name;
  final int age;
}
