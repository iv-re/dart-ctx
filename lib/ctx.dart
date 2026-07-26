import 'dart:async';

final Future<void> _neverEndingFuture = Completer<void>().future;

/// Base class for all exceptions related to [Context] cancellation or timeouts.
abstract class ContextException implements Exception {
  const ContextException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when a [Context] is explicitly canceled.
class ContextCancelException extends ContextException {
  const ContextCancelException() : super('context canceled');
}

/// Thrown when a [Context] exceeds its timeout or deadline.
class ContextTimeoutException extends ContextException {
  const ContextTimeoutException() : super('context deadline exceeded');
}

/// A function used to cancel a [Context], optionally providing a [error].
typedef ContextCancelFn = void Function([Exception? error]);

/// A [Context] carries deadlines, cancellation signals, and scoped data across
/// API boundaries and between asynchronous processes.
///
/// Contexts are immutable — deriving a child from a parent never mutates
/// the parent.
abstract class Context {
  /// Creates an empty [Context] that is never canceled, has no values,
  /// and has no deadline.
  const factory Context.empty() = _EmptyContext;

  /// The time when work done on behalf of this context should be canceled.
  /// Returns `null` if no deadline is set.
  DateTime? get deadline;

  /// A future that completes when this context is canceled or times out.
  /// Use this to monitor for cancellation.
  Future<void> get done;

  /// The exception that caused this context to close, or `null` if it is still
  /// active.
  Exception? get error;

  /// Retrieves a value by [key], or `null` if not found.
  Object? value(Object key);
}

class _EmptyContext implements Context {
  const _EmptyContext();

  @override
  DateTime? get deadline => null;

  @override
  Future<void> get done => _neverEndingFuture;

  @override
  Exception? get error => null;

  @override
  Object? value(Object key) => null;
}

class _CancelContext implements Context {
  _CancelContext(this._parent) {
    if (_parent.error != null) {
      _cancel(_parent.error);
    } else if (!identical(_parent.done, _neverEndingFuture)) {
      _parent.done.whenComplete(() => _cancel(_parent.error));
    }
  }

  final Context _parent;
  final Completer<void> _done = Completer<void>();

  Exception? _error;

  @override
  DateTime? get deadline => _parent.deadline;

  @override
  Future<void> get done => _done.future;

  @override
  Exception? get error => _error;

  @override
  Object? value(Object key) => _parent.value(key);

  void _cancel([Exception? reason]) {
    if (_done.isCompleted) return;
    _error = reason ?? const ContextCancelException();
    _done.complete();
  }
}

class _WithoutCancelContext implements Context {
  const _WithoutCancelContext(this._parent);

  final Context _parent;

  @override
  Future<void> get done => _neverEndingFuture;

  @override
  Exception? get error => null;

  @override
  DateTime? get deadline => null;

  @override
  Object? value(Object key) => _parent.value(key);
}

class _TimeoutContext implements Context {
  _TimeoutContext({
    required this._parent,
    required Duration timeout,
  }) : _deadline = DateTime.now().add(timeout) {
    _timer = Timer(timeout, () {
      _cancel(const ContextTimeoutException());
    });

    if (_parent.error != null) {
      _cancel(_parent.error);
    } else if (!identical(_parent.done, _neverEndingFuture)) {
      _parent.done.whenComplete(() => _cancel(_parent.error));
    }
  }

  final Context _parent;
  final DateTime _deadline;

  late final Timer _timer;
  final Completer<void> _done = Completer<void>();
  Exception? _error;

  @override
  Future<void> get done => _done.future;

  @override
  Exception? get error => _error;

  @override
  DateTime? get deadline {
    final parentDeadline = _parent.deadline;
    if (parentDeadline != null && parentDeadline.isBefore(_deadline)) {
      return parentDeadline;
    }
    return _deadline;
  }

  @override
  Object? value(Object key) => _parent.value(key);

  void _cancel([Exception? reason]) {
    if (_done.isCompleted) return;
    _timer.cancel();
    _error = reason ?? const ContextCancelException();
    _done.complete();
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
  DateTime? get deadline => _parent.deadline;

  @override
  Future<void> get done => _parent.done;

  @override
  Exception? get error => _parent.error;

  @override
  Object? value(Object key) {
    if (_key == key) return _value;
    return _parent.value(key);
  }
}

extension ContextExtensions on Context {
  /// Retrieves a value by [key], or `null` if not found.
  Object? operator [](Object key) => value(key);

  /// Returns a new [Context] containing all values from this context
  /// plus the given [key]-[value] pair.
  ///
  /// If [key] already exists in this context, the new value *shadows* the
  /// existing one. The original context is not modified.
  ///
  /// ```dart
  /// final ctx = Context.empty().withValue('user', 'alice');
  /// print(ctx['user']); // alice
  /// ```
  Context withValue(Object key, Object value) {
    return _ValueContext(parent: this, key: key, value: value);
  }

  /// Returns a derived [Context] and a function to cancel it.
  ///
  /// Calling the returned [ContextCancelFn] completes the [done] future
  /// and propagates the cancellation to all child contexts.
  ///
  /// ```dart
  /// final (ctx, cancel) = Context.empty().withCancel();
  ///
  /// ctx.done.then((_) => print('Context was canceled!'));
  /// cancel(); // Triggers the print statement and releases resources
  /// ```
  (Context, ContextCancelFn) withCancel() {
    final cancelCtx = _CancelContext(this);
    return (cancelCtx, cancelCtx._cancel);
  }

  /// Returns a copy of this [Context] that is never canceled,
  /// even if this parent context is canceled.
  // ignore: use_to_and_as_if_applicable
  Context withoutCancel() => _WithoutCancelContext(this);

  /// Returns a derived [Context] that automatically cancels after [timeout].
  ///
  /// The returned [ContextCancelFn] can be used to cancel the context
  /// before the timeout expires to release resources early.
  ///
  /// ```dart
  /// final (ctx, cancel) =
  ///     Context.empty().withTimeout(const Duration(seconds: 5));
  ///
  /// try {
  ///   // Pass `ctx` to your async operation...
  ///   await performNetworkRequest(ctx);
  /// } finally {
  ///   cancel(); // Clean up the timer if the request finishes early
  /// }
  /// ```
  (Context, ContextCancelFn) withTimeout(Duration timeout) {
    final timeoutCtx = _TimeoutContext(
      parent: this,
      timeout: timeout,
    );
    return (timeoutCtx, timeoutCtx._cancel);
  }

  /// Returns a derived [Context] that automatically cancels at a specific
  /// [deadline].
  ///
  /// ```dart
  /// final deadline = DateTime.now().add(const Duration(minutes: 1));
  /// final (ctx, cancel) = Context.empty().withDeadline(deadline);
  /// ```
  (Context, ContextCancelFn) withDeadline(DateTime deadline) {
    final timeout = deadline.difference(DateTime.now());
    return withTimeout(timeout);
  }
}
