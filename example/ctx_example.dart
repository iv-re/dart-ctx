import 'package:ctx/ctx.dart';

void main() async {
  // Carrying values
  final ctx = const Context.empty()
      .withValue('user', 'alice')
      .withValue('role', 'admin');

  print('User: ${ctx['user']}'); // alice

  // Derive a new context without mutating the original:
  final scoped = ctx.withValue('role', 'editor');
  print('Original role: ${ctx['role']}'); // admin
  print('Scoped role: ${scoped['role']}'); // editor

  // Cancellation
  final (cancelCtx, cancel) = ctx.withCancel();

  cancel();
  await cancelCtx.done;

  print('Canceled? ${cancelCtx.error != null}'); // true

  // Zone propagation
  ctx.run(() {
    print('Current user from Zone: ${Context.current['user']}'); // alice
  });
}
