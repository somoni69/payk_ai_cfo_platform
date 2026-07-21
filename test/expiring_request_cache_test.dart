import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/expiring_request_cache.dart';

void main() {
  test('deduplicates in-flight loads and reuses a fresh value', () async {
    final cache = ExpiringRequestCache<int>();
    final pending = Completer<int>();
    var loads = 0;

    Future<int> loader() {
      loads++;
      return pending.future;
    }

    final first = cache.get(loader);
    final second = cache.get(loader);
    expect(loads, 1);

    pending.complete(42);
    expect(await first, 42);
    expect(await second, 42);
    expect(await cache.get(loader), 42);
    expect(loads, 1);
  });

  test(
    'global invalidation prevents data leaking into a new session',
    () async {
      final cache = ExpiringRequestCache<int>();
      var value = 1;

      expect(await cache.get(() async => value), 1);
      value = 2;
      ExpiringRequestCache.invalidateAll();

      expect(await cache.get(() async => value), 2);
    },
  );

  test('late completion from an old session cannot poison the cache', () async {
    final cache = ExpiringRequestCache<int>();
    final oldSession = Completer<int>();
    final newSession = Completer<int>();

    final oldRequest = cache.get(() => oldSession.future);
    ExpiringRequestCache.invalidateAll();
    final newRequest = cache.get(() => newSession.future);

    newSession.complete(2);
    expect(await newRequest, 2);

    oldSession.complete(1);
    expect(await oldRequest, 1);
    expect(await cache.get(() async => 3), 2);
  });

  test('local invalidation detaches an in-flight request', () async {
    final cache = ExpiringRequestCache<int>();
    final stale = Completer<int>();

    final staleRequest = cache.get(() => stale.future);
    cache.invalidate();
    expect(await cache.get(() async => 7), 7);

    stale.complete(3);
    expect(await staleRequest, 3);
    expect(cache.valueOrNull, 7);
  });

  test('force refresh replaces cached and in-flight data', () async {
    final cache = ExpiringRequestCache<int>();
    final stale = Completer<int>();

    final staleRequest = cache.get(() => stale.future);
    final refreshed = cache.get(() async => 9, forceRefresh: true);

    expect(await refreshed, 9);
    stale.complete(4);
    expect(await staleRequest, 4);
    expect(cache.valueOrNull, 9);
  });

  test('set supersedes an in-flight request', () async {
    final cache = ExpiringRequestCache<int>();
    final pending = Completer<int>();

    final request = cache.get(() => pending.future);
    cache.set(12);
    pending.complete(5);

    expect(await request, 5);
    expect(cache.valueOrNull, 12);
  });
}
