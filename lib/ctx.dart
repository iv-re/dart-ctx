/// A [Context] carries data through an application.
///
/// Contexts are immutable — deriving a child from a parent never mutates
/// the parent.
///
/// Create an empty context with [Context.empty] and attach values with
/// [withValue]:
///
/// ```dart
/// final ctx = Context.empty().withValue('user', 'alice');
/// print(ctx['user']); // alice
/// ```
abstract class Context {
  /// Creates an empty [Context] that returns `null` for every key.
  const factory Context.empty() = _EmptyContext;

  /// Retrieves a value by [key], or `null` if not found.
  Object? operator [](Object key);

  /// Returns a new [Context] that contains all values from this context
  /// plus the given [key]-[value] pair.
  ///
  /// If [key] already exists in this context, the new value *shadows* the
  /// existing one — the original context is not modified.
  Context withValue(Object key, Object value);
}

class _EmptyContext implements Context {
  const _EmptyContext();

  @override
  Object? operator [](Object key) => null;

  @override
  Context withValue(Object key, Object value) {
    return _ValueContext(parent: this, key: key, value: value);
  }
}

class _ValueContext implements Context {
  const _ValueContext({
    required this._parent,
    required this._key,
    required this._value,
  });

  final Context _parent;
  final Object _key;
  final Object _value;

  @override
  Object? operator [](Object key) {
    if (_key == key) return _value;
    return _parent[key];
  }

  @override
  Context withValue(Object key, Object value) {
    return _ValueContext(parent: this, key: key, value: value);
  }
}
