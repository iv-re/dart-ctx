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
}
