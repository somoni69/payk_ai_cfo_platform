/// Small in-memory TTL cache with in-flight request de-duplication.
///
/// Repositories are application-scoped, so this keeps recently visited
/// secondary modules responsive without caching data across user sessions.
class ExpiringRequestCache<T> {
  ExpiringRequestCache({this.ttl = const Duration(seconds: 30)});

  static int _globalEpoch = 0;

  static void invalidateAll() => _globalEpoch++;

  final Duration ttl;
  T? _value;
  bool _hasValue = false;
  DateTime? _storedAt;
  Future<T>? _inFlight;
  int _epoch = _globalEpoch;
  int _generation = 0;

  Future<T> get(Future<T> Function() loader, {bool forceRefresh = false}) {
    _syncEpoch();
    if (forceRefresh) invalidate();

    final storedAt = _storedAt;
    if (!forceRefresh &&
        _hasValue &&
        storedAt != null &&
        DateTime.now().difference(storedAt) < ttl) {
      return Future<T>.value(_value as T);
    }

    final current = _inFlight;
    if (current != null) return current;

    final requestEpoch = _epoch;
    final requestGeneration = _generation;
    late final Future<T> request;
    request = Future<T>.sync(loader).then((value) {
      // A request may complete after logout/login or a local refresh. Return
      // the value to its original caller, but never publish it into the cache
      // for the newer session/generation.
      if (_globalEpoch == requestEpoch &&
          _epoch == requestEpoch &&
          _generation == requestGeneration &&
          identical(_inFlight, request)) {
        _value = value;
        _hasValue = true;
        _storedAt = DateTime.now();
      }
      return value;
    });
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  void invalidate() {
    _generation++;
    _value = null;
    _hasValue = false;
    _storedAt = null;
    _inFlight = null;
  }

  void set(T value) {
    _syncEpoch();
    invalidate();
    _value = value;
    _hasValue = true;
    _storedAt = DateTime.now();
  }

  /// Returns the fresh cached value, if one exists in the current session.
  T? get valueOrNull {
    _syncEpoch();
    final storedAt = _storedAt;
    if (!_hasValue ||
        storedAt == null ||
        DateTime.now().difference(storedAt) >= ttl) {
      return null;
    }
    return _value as T;
  }

  void _syncEpoch() {
    if (_epoch == _globalEpoch) return;
    invalidate();
    _epoch = _globalEpoch;
  }
}
