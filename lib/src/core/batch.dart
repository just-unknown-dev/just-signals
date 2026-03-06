library;

import 'signal.dart';

/// Batches multiple signal updates to defer notifications until the batch completes.
///
/// This prevents unnecessary intermediate rebuilds when updating multiple signals.
///
/// ```dart
/// batch(() {
///   x.value = 10;
///   y.value = 20;
///   z.value = 30;
/// }); // Only one notification at the end
/// ```
void batch(void Function() updates) {
  SignalBatch.run(updates);
}

/// Internal batch management.
class SignalBatch {
  SignalBatch._();

  static int _batchDepth = 0;
  static final Set<Signal<dynamic>> scheduledSignals = {};

  /// Whether we're currently in a batch.
  static bool get isBatching => _batchDepth > 0;

  /// Runs updates in a batch, deferring notifications.
  static void run(void Function() updates) {
    _batchDepth++;
    try {
      updates();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0) {
        _flushBatch();
      }
    }
  }

  /// Flushes all scheduled notifications.
  static void _flushBatch() {
    final signals = Set<Signal<dynamic>>.from(scheduledSignals);
    scheduledSignals.clear();

    for (final signal in signals) {
      signal.dispatchNotifications();
    }
  }
}

/// Runs updates in a transaction that can be rolled back on error.
///
/// If the updates throw, all signal values are restored to their previous state.
///
/// ```dart
/// transaction(() {
///   balance.value -= 100;
///   if (balance.value < 0) throw InsufficientFundsException();
/// }); // Rolls back if exception thrown
/// ```
void transaction(void Function() updates) {
  SignalTransaction.run(updates);
}

/// Internal transaction management.
class SignalTransaction {
  SignalTransaction._();

  static final Map<Signal<dynamic>, dynamic> _snapshots = {};
  static int _transactionDepth = 0;

  /// Whether we're currently in a transaction.
  static bool get isInTransaction => _transactionDepth > 0;

  /// Records a signal's value before modification.
  static void snapshot<T>(Signal<T> signal) {
    if (isInTransaction && !_snapshots.containsKey(signal)) {
      _snapshots[signal] = signal.value;
    }
  }

  /// Runs updates in a transaction.
  static void run(void Function() updates) {
    _transactionDepth++;
    final hadPreviousSnapshots = _snapshots.isNotEmpty;

    try {
      batch(updates);
    } catch (e) {
      // Rollback on error
      if (!hadPreviousSnapshots) {
        _rollback();
      }
      rethrow;
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        _snapshots.clear();
      }
    }
  }

  /// Rolls back all signals to their snapshot values.
  static void _rollback() {
    for (final entry in _snapshots.entries) {
      entry.key.setSilent(entry.value);
    }
    _snapshots.clear();
    SignalBatch.scheduledSignals.clear();
  }
}
