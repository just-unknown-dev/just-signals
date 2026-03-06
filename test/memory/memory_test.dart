import 'package:flutter_test/flutter_test.dart';
import 'package:just_signals/just_signals.dart';

void main() {
  group('MemoryArena', () {
    test('creates with capacity', () {
      final arena = MemoryArena(capacity: 100);
      expect(arena.capacity, 100);
      expect(arena.allocatedCount, 0);
      expect(arena.availableCount, 100);
    });

    test('allocates slots', () {
      final arena = MemoryArena(capacity: 10);

      final slot1 = arena.allocate();
      final slot2 = arena.allocate();

      expect(slot1, isNot(slot2));
      expect(arena.allocatedCount, 2);
      expect(arena.isAllocated(slot1), true);
      expect(arena.isAllocated(slot2), true);
    });

    test('frees slots', () {
      final arena = MemoryArena(capacity: 10);

      final slot = arena.allocate();
      expect(arena.allocatedCount, 1);

      arena.free(slot);
      expect(arena.allocatedCount, 0);
      expect(arena.isAllocated(slot), false);
    });

    test('reuses freed slots', () {
      final arena = MemoryArena(capacity: 10);

      final slot1 = arena.allocate();
      arena.free(slot1);
      final slot2 = arena.allocate();

      expect(slot2, slot1); // Reused the freed slot
    });

    test('returns -1 when full', () {
      final arena = MemoryArena(capacity: 2);

      arena.allocate();
      arena.allocate();
      final slot = arena.allocate();

      expect(slot, -1);
      expect(arena.isFull, true);
    });

    test('sets and gets position', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();

      arena.setPosition(slot, 100.0, 200.0);

      expect(arena.getX(slot), 100.0);
      expect(arena.getY(slot), 200.0);
    });

    test('translates position', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();

      arena.setPosition(slot, 100.0, 200.0);
      arena.translate(slot, 10.0, 20.0);

      expect(arena.getX(slot), 110.0);
      expect(arena.getY(slot), 220.0);
    });

    test('sets and gets rotation', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();

      arena.setRotation(slot, 3.14);
      expect(arena.getRotation(slot), 3.14);

      arena.rotate(slot, 0.5);
      expect(arena.getRotation(slot), 3.64);
    });

    test('sets and gets scale', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();

      arena.setScale(slot, 2.0);
      expect(arena.getScaleX(slot), 2.0);
      expect(arena.getScaleY(slot), 2.0);

      arena.setScaleXY(slot, 3.0, 4.0);
      expect(arena.getScaleX(slot), 3.0);
      expect(arena.getScaleY(slot), 4.0);
    });

    test('sets and gets velocity', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();

      arena.setVelocity(slot, 50.0, -30.0);
      expect(arena.getVelocityX(slot), 50.0);
      expect(arena.getVelocityY(slot), -30.0);
    });

    test('applies velocity', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();

      arena.setPosition(slot, 0.0, 0.0);
      arena.setVelocity(slot, 100.0, 50.0);
      arena.applyVelocity(slot, 0.5); // 0.5 seconds

      expect(arena.getX(slot), 50.0);
      expect(arena.getY(slot), 25.0);
    });

    test('forEach iterates allocated slots', () {
      final arena = MemoryArena(capacity: 10);

      arena.allocate();
      arena.allocate();
      arena.allocate();

      int count = 0;
      arena.forEach((_) => count++);

      expect(count, 3);
    });

    test('clear resets arena', () {
      final arena = MemoryArena(capacity: 10);

      arena.allocate();
      arena.allocate();
      arena.clear();

      expect(arena.allocatedCount, 0);
      expect(arena.availableCount, 10);
    });
  });

  group('ObjectPool', () {
    test('creates objects on demand', () {
      int createCount = 0;
      final pool = ObjectPool<int>(create: () => ++createCount);

      final a = pool.acquire();
      final b = pool.acquire();

      expect(a, 1);
      expect(b, 2);
      expect(createCount, 2);
    });

    test('reuses released objects', () {
      int createCount = 0;
      final pool = ObjectPool<int>(create: () => ++createCount);

      final a = pool.acquire();
      pool.release(a);
      final b = pool.acquire();

      expect(b, a); // Reused
      expect(createCount, 1); // Only created once
    });

    test('calls reset on release', () {
      final values = <int>[];
      final pool = ObjectPool<int>(
        create: () => 0,
        reset: (v) => values.add(v),
      );

      final a = pool.acquire();
      pool.release(a);

      expect(values, [0]);
    });

    test('prewarms pool', () {
      int createCount = 0;
      final pool = ObjectPool<int>(create: () => ++createCount, initialSize: 5);

      expect(createCount, 5);
      expect(pool.availableCount, 5);
    });

    test('tracks in-use count', () {
      // Use object type to ensure unique instances
      final pool = ObjectPool<List<int>>(create: () => <int>[], initialSize: 5);

      pool.acquire();
      pool.acquire();

      expect(pool.inUseCount, 2);
      expect(pool.availableCount, 3);
    });

    test('releaseAll releases all objects', () {
      final pool = ObjectPool<List<int>>(create: () => <int>[], initialSize: 5);

      pool.acquire();
      pool.acquire();
      pool.acquire();
      pool.releaseAll();

      expect(pool.inUseCount, 0);
      expect(pool.availableCount, 5); // All objects returned to pool
    });
  });

  group('RoundRobinPool', () {
    test('cycles through objects', () {
      final pool = RoundRobinPool<int>(create: () => 0, size: 3);

      // Access multiple times
      final results = <int>[];
      for (var i = 0; i < 6; i++) {
        results.add(pool.currentIndex);
        pool.next();
      }

      expect(results, [0, 1, 2, 0, 1, 2]); // Cycles
    });

    test('calls onRecycle', () {
      int recycleCount = 0;
      final pool = RoundRobinPool<int>(
        create: () => 0,
        size: 3,
        onRecycle: (_) => recycleCount++,
      );

      pool.next();
      pool.next();

      expect(recycleCount, 2);
    });
  });

  group('TypedVec2', () {
    test('backed by arena', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();
      final vec = TypedVec2(arena, slot);

      vec.x = 100.0;
      vec.y = 200.0;

      expect(arena.getX(slot), 100.0);
      expect(arena.getY(slot), 200.0);
    });

    test('temp vectors work without arena', () {
      final vec = TypedVec2.temp(10.0, 20.0);

      expect(vec.x, 10.0);
      expect(vec.y, 20.0);

      vec.x = 30.0;
      expect(vec.x, 30.0);
    });

    test('add works', () {
      final arena = MemoryArena(capacity: 10);
      final slot = arena.allocate();
      final vec = TypedVec2(arena, slot);

      vec.set(10.0, 20.0);
      vec.add(TypedVec2.temp(5.0, 10.0));

      expect(vec.x, 15.0);
      expect(vec.y, 30.0);
    });

    test('length calculation', () {
      final vec = TypedVec2.temp(3.0, 4.0);
      expect(vec.lengthSquared, 25.0);
      expect(vec.length, closeTo(5.0, 0.001));
    });
  });

  group('PoolManager', () {
    setUp(() {
      PoolManager.resetInstance();
    });

    test('registers and retrieves pools', () {
      final manager = PoolManager.instance;
      final pool = ObjectPool<int>(create: () => 0);

      manager.registerPool('test', pool);

      expect(manager.hasPool('test'), true);
      expect(manager.pool<int>('test'), pool);
    });

    test('creates arenas', () {
      final manager = PoolManager.instance;
      final arena = manager.createArena('entities', capacity: 100);

      expect(arena.capacity, 100);
      expect(manager.hasArena('entities'), true);
    });

    test('provides statistics', () {
      final manager = PoolManager.instance;
      manager.createArena('test', capacity: 100);

      final stats = manager.getArenaStats();
      expect(stats['test']!.capacity, 100);
    });
  });
}
