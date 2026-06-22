# ctx

An immutable context for carrying data through your application.

## Usage

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