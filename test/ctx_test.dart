import 'dart:async';

import 'package:ctx/ctx.dart';
import 'package:test/test.dart';

void main() {
  group('Context.empty', () {
    test('returns null for any key', () {
      const context = Context.empty();
      expect(context['key'], isNull);
    });
  });

  group('Context.withValue', () {
    test('stores and retrieves a value', () {
      final context = const Context.empty().withValue('key', 'value');
      expect(context['key'], 'value');
    });

    test('returns null for unknown keys', () {
      final context = const Context.empty().withValue('key', 'value');
      expect(context['other'], isNull);
    });

    test('multiple values can be stored independently', () {
      final context = const Context.empty().withValue('a', 1).withValue('b', 2);

      expect(context['a'], 1);
      expect(context['b'], 2);
    });

    test('inner value shadows outer value for the same key', () {
      final context = const Context.empty()
          .withValue('key', 'outer')
          .withValue('key', 'inner');

      expect(context['key'], 'inner');
    });

    test('original context is unchanged after adding a value', () {
      final outer = const Context.empty().withValue('a', 1);
      final inner = outer.withValue('b', 2);

      expect(outer['a'], 1);
      expect(outer['b'], isNull);

      expect(inner['a'], 1);
      expect(inner['b'], 2);
    });

    test('can store different value types', () {
      final context = const Context.empty()
          .withValue('string', 'hello')
          .withValue('int', 42)
          .withValue('bool', true)
          .withValue('list', [1, 2, 3]);

      expect(context['string'], 'hello');
      expect(context['int'], 42);
      expect(context['bool'], true);
      expect(context['list'], [1, 2, 3]);
    });

    test('can store and retrieve values using non-string keys', () {
      final keyObject = Object();

      final context = const Context.empty()
          .withValue(keyObject, 'value_obj')
          .withValue(int, 'value_type');

      expect(context[keyObject], 'value_obj');
      expect(context[int], 'value_type');
    });
  });

  group('Context.withCancel', () {
    test(
      'calling cancel completes done and sets error to ContextCancelException',
      () async {
        final (ctx, cancel) = const Context.empty().withCancel();

        cancel();

        await expectLater(ctx.done, completes);
        expect(ctx.error, isA<ContextCancelException>());
      },
    );

    test(
      'calling cancel with custom exception sets it as the error',
      () async {
        final (ctx, cancel) = const Context.empty().withCancel();
        final customException = Exception('custom reason');

        cancel(customException);

        await expectLater(ctx.done, completes);
        expect(ctx.error, customException);
      },
    );

    test('subsequent cancel calls are ignored', () async {
      final (ctx, cancel) = const Context.empty().withCancel();

      cancel(Exception('first'));
      cancel(Exception('second'));

      await expectLater(ctx.done, completes);
      expect(ctx.error.toString(), contains('first'));
    });

    test('parent cancellation propagates to child', () async {
      final (parent, cancelParent) = const Context.empty().withCancel();
      final (child, _) = parent.withCancel();

      cancelParent();

      await expectLater(child.done, completes);
      expect(child.error, isA<ContextCancelException>());
    });

    test(
      'parent custom exception cancellation propagates to child',
      () async {
        final (parent, cancelParent) = const Context.empty().withCancel();
        final (child, _) = parent.withCancel();
        final custom = Exception('parent custom');

        cancelParent(custom);

        await expectLater(child.done, completes);
        expect(child.error, custom);
      },
    );

    test(
      'if parent is already canceled, child is created canceled',
      () async {
        final (parent, cancelParent) = const Context.empty().withCancel();
        cancelParent();

        final (child, _) = parent.withCancel();

        await expectLater(child.done, completes);
        expect(child.error, isA<ContextCancelException>());
      },
    );

    test('inherits values and deadline from parent', () {
      final parent = const Context.empty().withValue('key', 'val');

      final (child, _) = parent.withCancel();

      expect(child['key'], 'val');
      expect(child.deadline, isNull);
    });
  });

  group('Context.withoutCancel', () {
    test('does not propagate cancellation from parent', () async {
      final (parent, cancelParent) = const Context.empty().withCancel();
      final child = parent.withoutCancel();

      cancelParent();
      await expectLater(parent.done, completes);

      var childCompleted = false;
      unawaited(child.done.then((_) => childCompleted = true));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(childCompleted, isFalse);
      expect(child.error, isNull);
      expect(child.deadline, isNull);
    });

    test('inherits values from parent', () {
      final parent = const Context.empty().withValue('key', 'val');

      final child = parent.withoutCancel();

      expect(child['key'], 'val');
    });
  });

  group('Context.withTimeout', () {
    test('cancels automatically after timeout', () async {
      final (ctx, _) = const Context.empty().withTimeout(
        const Duration(milliseconds: 50),
      );

      await expectLater(ctx.done, completes);
      expect(ctx.error, isA<ContextTimeoutException>());
    });

    test('can be canceled explicitly before timeout', () async {
      final (ctx, cancel) = const Context.empty().withTimeout(
        const Duration(seconds: 10),
      );

      cancel();

      await expectLater(ctx.done, completes);
      expect(ctx.error, isA<ContextCancelException>());
    });

    test('parent cancellation propagates to timeout child', () async {
      final (parent, cancelParent) = const Context.empty().withCancel();
      final (child, _) = parent.withTimeout(const Duration(seconds: 10));

      cancelParent();

      await expectLater(child.done, completes);
      expect(child.error, isA<ContextCancelException>());
    });

    test('inherits minimum deadline', () {
      final now = DateTime.now();
      final (parent, _) = const Context.empty().withTimeout(
        const Duration(seconds: 2),
      );

      final (childShort, _) = parent.withTimeout(const Duration(seconds: 5));
      final (childLong, _) = parent.withTimeout(const Duration(seconds: 1));

      expect(childShort.deadline, isNotNull);
      expect(
        childShort.deadline!.difference(now).inSeconds,
        closeTo(2, 1),
      );
      expect(childLong.deadline, isNotNull);
      expect(
        childLong.deadline!.difference(now).inSeconds,
        closeTo(1, 1),
      );
    });

    test(
      'if parent is already canceled, timeout child is created canceled',
      () async {
        final (parent, cancelParent) = const Context.empty().withCancel();
        cancelParent();

        final (child, _) = parent.withTimeout(const Duration(seconds: 10));

        await expectLater(child.done, completes);
        expect(child.error, isA<ContextCancelException>());
      },
    );

    test('propagates value lookups to parent', () {
      final parent = const Context.empty().withValue('key', 'val');

      final (child, _) = parent.withTimeout(const Duration(seconds: 10));

      expect(child['key'], 'val');
    });
  });

  group('Context.withDeadline', () {
    test('cancels automatically at deadline', () async {
      final deadline = DateTime.now().add(const Duration(milliseconds: 50));
      final (ctx, _) = const Context.empty().withDeadline(deadline);

      await expectLater(ctx.done, completes);
      expect(ctx.error, isA<ContextTimeoutException>());
    });
  });

  group('ContextException', () {
    test('toString returns the message', () {
      const exception = ContextCancelException();

      final str = exception.toString();

      expect(str, 'context canceled');
    });
  });
}
