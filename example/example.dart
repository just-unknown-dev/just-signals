// ignore_for_file: avoid_print

/// just_signals — pub.dev example
///
/// A self-contained Flutter app demonstrating:
///   • `Signal<T>`            reactive primitives
///   • `Computed<T>`          derived values
///   • Effect               auto-tracked side effects
///   • batch() / SignalBatch.run()  coalesced updates
///   • transaction()        rollback-safe mutation
///   • `SignalBuilder<T>`     surgical single-signal widget rebuild
///   • SignalConsumer        multi-signal widget rebuild
///   • `ObjectPool<T>`        zero-GC object reuse
///   • `AsyncSignal<T>`       async loading / error / data states
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';

void main() => runApp(const _App());

// ────────────────────────────────────────────────────────────────────────────
// State — all reactive state in one place
// ────────────────────────────────────────────────────────────────────────────

/// Holds every piece of mutable game state as `Signal<T>`.
/// Derived values are `Computed<T>` — never set directly.
/// All multi-signal mutations go through action methods that use batch().
class CounterState {
  // ── Mutable signals ───────────────────────────────────────────────────────
  final count = Signal<int>(0, debugLabel: 'count');
  final multiplier = Signal<int>(1, debugLabel: 'multiplier');
  final history = Signal<List<String>>([], debugLabel: 'history');

  // ── Computed (derived, auto-tracked) ─────────────────────────────────────
  late final Computed<int> score;
  late final Computed<String> grade;
  late final Computed<bool> isHighScore;

  // ── Effect — logs every score change ─────────────────────────────────────
  late final Effect _logger;

  CounterState() {
    // score derives from two signals automatically
    score = Computed(() => count.value * multiplier.value, debugLabel: 'score');

    // grade derives from score (a chain of Computed)
    grade = Computed(() {
      final s = score.value;
      if (s >= 100) return 'S';
      if (s >= 50) return 'A';
      if (s >= 20) return 'B';
      if (s >= 5) return 'C';
      return 'D';
    }, debugLabel: 'grade');

    isHighScore = Computed(() => score.value >= 50, debugLabel: 'isHighScore');

    // Effect fires whenever score changes (immediate: false → skip first run)
    _logger = Effect(() {
      final s = score.value;
      if (s != 0) {
        // Use microtask to avoid mutating a signal mid-notification
        Future.microtask(
          () => history.update(
            (h) => [...h, 'score → $s (grade ${grade.value})'],
          ),
        );
      }
      return null; // no cleanup needed
    }, immediate: false);
  }

  // ── Action methods — batch all related mutations ──────────────────────────

  /// Increment count by 1.
  void increment() => count.update((c) => c + 1);

  /// Decrement count by 1 (min 0).
  void decrement() => count.update((c) => (c - 1).clamp(0, 9999));

  /// Double the multiplier in the same batch as a count increment.
  void powerUp() {
    batch(() {
      count.update((c) => c + 5);
      multiplier.update((m) => m * 2);
      history.update((h) => [...h, '⚡ Power-up! ×${multiplier.value * 2}']);
    });
  }

  /// Reset via transaction — rolls back if something goes wrong.
  void reset() {
    transaction(() {
      count.value = 0;
      multiplier.value = 1;
      history.value = [];
    });
  }

  void dispose() => _logger.dispose();
}

// ────────────────────────────────────────────────────────────────────────────
// ObjectPool demo object
// ────────────────────────────────────────────────────────────────────────────

class _Event {
  int value = 0;
  void reset() => value = 0;
}

// ────────────────────────────────────────────────────────────────────────────
// App
// ────────────────────────────────────────────────────────────────────────────

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Signals Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0a0a1a),
        cardColor: const Color(0xFF0f0f2e),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF16f4d0),
          surface: Color(0xFF0f0f2e),
        ),
      ),
      home: const _ExamplePage(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Page
// ────────────────────────────────────────────────────────────────────────────

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  final _state = CounterState();

  // ObjectPool: pre-allocate 10 _Event objects — no heap churn after warm-up
  final _pool = ObjectPool<_Event>(
    create: () => _Event(),
    reset: (e) => e.reset(),
    initialSize: 10,
  );

  // AsyncSignal: wraps a simulated async fetch
  final _asyncMsg = AsyncSignal<String>();

  @override
  void initState() {
    super.initState();
    _fetchMessage();
  }

  Future<void> _fetchMessage() async {
    await _asyncMsg.load(() async {
      await Future.delayed(const Duration(seconds: 1));
      return 'Player profile loaded from server ✓';
    });
  }

  /// Fire score event via ObjectPool — acquire → use → release
  void _poolFire() {
    final event = _pool.acquire();
    event.value = math.Random().nextInt(5) + 1;
    _state.count.update((c) => c + event.value);
    _pool.release(event); // back to pool — no GC
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f2e),
        title: const Text(
          'Just Signals',
          style: TextStyle(
            color: Color(0xFF16f4d0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. SignalBuilder — single signal rebuild ──────────────────────
          _Section(
            label: '1 · SignalBuilder  (single signal rebuild)',
            child: Column(
              children: [
                // Only this widget rebuilds when score changes
                SignalBuilder<int>(
                  signal: _state.score,
                  builder: (_, score, _) => Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16f4d0),
                    ),
                  ),
                ),

                // Named chain: count × multiplier = score
                SignalConsumer(
                  signals: [_state.count, _state.multiplier],
                  builder: (_, _) => Text(
                    '${_state.count.value}  ×  ${_state.multiplier.value}  =  ${_state.score.value}',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 8),

                // Grade from chained Computed
                SignalBuilder<String>(
                  signal: _state.grade,
                  builder: (_, g, _) => Chip(
                    label: Text(
                      'Grade  $g',
                      style: const TextStyle(
                        color: Color(0xFF16f4d0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: const Color(
                      0xFF16f4d0,
                    ).withValues(alpha: 0.1),
                    side: const BorderSide(color: Color(0xFF16f4d0)),
                  ),
                ),

                const SizedBox(height: 8),

                // isHighScore Computed drives UI state
                SignalBuilder<bool>(
                  signal: _state.isHighScore,
                  builder: (_, hi, _) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: hi
                          ? const Color(0xFF16f4d0).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hi ? const Color(0xFF16f4d0) : Colors.white12,
                      ),
                    ),
                    child: Text(
                      hi ? '🏆  HIGH SCORE!' : 'Reach 50 for high score',
                      style: TextStyle(
                        color: hi ? const Color(0xFF16f4d0) : Colors.white24,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 2. Actions: batch() + transaction() ──────────────────────────
          _Section(
            label: '2 · batch() + transaction()',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Btn('+1', Icons.add, () => _state.increment()),
                _Btn('-1', Icons.remove, () => _state.decrement()),
                _Btn('⚡ Power-up\n(batch)', Icons.bolt, () => _state.powerUp()),
                _Btn(
                  'Reset\n(transaction)',
                  Icons.refresh,
                  () => _state.reset(),
                  danger: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 3. ObjectPool ─────────────────────────────────────────────────
          _Section(
            label: '3 · ObjectPool  (zero-GC reuse)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'acquire() → use → release()  —  no heap allocation after warm-up.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16f4d0),
                          side: const BorderSide(color: Color(0xFF16f4d0)),
                        ),
                        icon: const Icon(Icons.recycling, size: 16),
                        label: const Text('Acquire → Add → Release'),
                        onPressed: _poolFire,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Pool stats update via a simple StatefulBuilder
                // (pool doesn't use Signals internally — shown for completeness)
                Builder(
                  builder: (_) => Text(
                    'Pool: ${_pool.availableCount} available · '
                    '${_pool.inUseCount} in use · '
                    '${_pool.totalCreated} total created',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 4. AsyncSignal ────────────────────────────────────────────────
          _Section(
            label: '4 · AsyncSignal  (loading / error / data)',
            child: Column(
              children: [
                SignalBuilder(
                  signal: _asyncMsg,
                  builder: (_, snap, _) {
                    if (snap.isLoading) {
                      return const Row(
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF16f4d0),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Loading…',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      );
                    }
                    if (snap.hasError) {
                      return Text(
                        'Error: ${snap.error}',
                        style: TextStyle(color: Colors.red.shade300),
                      );
                    }
                    return Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF4CAF50),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            snap.data ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16f4d0),
                      side: const BorderSide(color: Color(0xFF16f4d0)),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reload'),
                    onPressed: _fetchMessage,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 5. Effect log ─────────────────────────────────────────────────
          _Section(
            label: '5 · Effect  (auto-tracked side effect)',
            child: SignalBuilder<List<String>>(
              signal: _state.history,
              builder: (_, entries, _) {
                if (entries.isEmpty) {
                  return const Text(
                    'No events yet. Press +1 or ⚡ Power-up above.',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...entries.reversed
                        .take(6)
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              e,
                              style: TextStyle(
                                color: e.startsWith('⚡')
                                    ? const Color(0xFFFFD700)
                                    : Colors.white38,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    if (entries.length > 6)
                      Text(
                        '… ${entries.length - 6} earlier entries',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final Widget child;

  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF16f4d0),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const Divider(color: Colors.white12, height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  const _Btn(this.label, this.icon, this.onPressed, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: danger ? Colors.red.shade900 : const Color(0xFF16f4d0),
        foregroundColor: danger ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }
}
