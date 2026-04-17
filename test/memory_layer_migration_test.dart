import 'package:flutter_test/flutter_test.dart';
import 'package:just_signals/just_signals.dart';

void main() {
  test('shared memory layer stays available from just_signals', () {
    final pool = ObjectPool<String>(
      create: () => 'signal',
      initialSize: 1,
      maxSize: 2,
    );

    final value = pool.acquire();
    pool.release(value);

    final arena = MemoryArena(capacity: 4);
    final slot = arena.allocate();
    arena.setPosition(slot, 10, 20);

    final buffer = TypedBuffer<double>.float64(4);
    buffer.setFloat(0, 3.14);

    final manager = PoolManager.instance;
    if (!manager.hasPool('signals.test')) {
      manager.registerPool<String>('signals.test', pool);
    }

    expect(pool.availableCount, 1);
    expect(arena.getX(slot), 10);
    expect(buffer.getFloat(0), closeTo(3.14, 0.001));
    expect(manager.pool<String>('signals.test'), same(pool));

    manager.unregisterPool('signals.test');
    manager.clearAllArenas();
  });
}
