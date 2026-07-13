import 'package:alarm/utils/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateTimeExtension.isSameSecond', () {
    test('true for identical instants', () {
      final dt = DateTime(2030, 1, 2, 3, 4, 5);

      expect(dt.isSameSecond(dt), isTrue);
    });

    test('true for instants within the same second', () {
      final a = DateTime(2030, 1, 2, 3, 4, 5, 100);
      final b = DateTime(2030, 1, 2, 3, 4, 5, 900);

      expect(a.isSameSecond(b), isTrue);
    });

    test('false for instants in different seconds', () {
      final a = DateTime(2030, 1, 2, 3, 4, 5, 900);
      final b = DateTime(2030, 1, 2, 3, 4, 6, 100);

      expect(a.isSameSecond(b), isFalse);
    });

    test('compares on the absolute timeline for UTC vs local', () {
      final local = DateTime(2030, 1, 2, 3, 4, 5);
      final sameInstantUtc = local.toUtc();

      expect(local.isSameSecond(sameInstantUtc), isTrue);
    });
  });
}
