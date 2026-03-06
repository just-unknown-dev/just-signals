/// A high-performance signal-driven state management library for Flutter.
///
/// just_signals provides:
/// - **Core Signals**: Reactive primitives with surgical precision updates
/// - **Memory Layer**: Zero-GC memory pooling with typed arrays and object pools
/// - **Flutter Widgets**: Efficient rebuilding with SignalBuilder and SignalConsumer
/// - **Async Support**: AsyncSignal, StreamSignal, and FutureSignal for async operations
///
/// ## Quick Start
///
/// ```dart
/// import 'package:just_signals/just_signals.dart';
///
/// // Create a signal
/// final count = Signal(0);
///
/// // Update the signal
/// count.value++;
///
/// // Use in a widget
/// SignalBuilder<int>(
///   signal: count,
///   builder: (context, value, child) => Text('Count: $value'),
/// );
/// ```
library;

// Core signals
export 'src/core/signal.dart';
export 'src/core/computed.dart';
export 'src/core/effect.dart';
export 'src/core/batch.dart';
export 'src/core/scope.dart';
export 'src/core/selector.dart';

// Memory layer (zero-GC)
export 'src/memory/memory_arena.dart';
export 'src/memory/object_pool.dart';
export 'src/memory/typed_buffer.dart';
export 'src/memory/pool_manager.dart';

// Flutter widgets
export 'src/widgets/signal_builder.dart';
export 'src/widgets/signal_scope_widget.dart';
export 'src/widgets/signal_listenable.dart';

// Async support
export 'src/async/async_signal.dart';
export 'src/async/stream_signal.dart';
export 'src/async/future_signal.dart';
