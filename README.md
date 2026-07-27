# ctx

An immutable context for carrying data, deadlines, and cancellation signals through your application.

## Usage

### Carrying Values

```dart
import 'package:ctx/ctx.dart';

void main() {
  final ctx = Context.empty()
      .withValue('user', 'alice')
      .withValue('role', 'admin');

  print(ctx['user']); // alice

  // Derive a new context without mutating the original:
  final scoped = ctx.withValue('role', 'editor');
  print(ctx['role']);    // admin
  print(scoped['role']); // editor
}
```

### Cancellation & Timeouts

```dart
// Explicit cancellation
final (ctx, cancel) = Context.empty().withCancel();
cancel();

// Automatic timeout
final (ctxTimeout, cancelTimeout) = Context.empty().withTimeout(Duration(seconds: 5));

// Non-cancelable branch
final detached = ctx.withoutCancel();
```

### Zone Propagation

You can propagate a context implicitly down an execution tree using `run`:

```dart
final ctx = Context.empty().withValue('user', 'alice');

ctx.run(() {
  print(Context.current['user']); // alice
});
```