import 'package:flutter_test/flutter_test.dart';
import 'package:zimo_jizhang/core/utils.dart';

void main() {
  group('MoneyUtils', () {
    test('converts yuan to fen without floating point drift', () {
      expect(MoneyUtils.yuanToFen(35.80), 3580);
      expect(MoneyUtils.yuanToFen(0.01), 1);
    });

    test('formats fen with two decimals', () {
      expect(MoneyUtils.fenToYuan(3580, showSymbol: false), '35.80');
      expect(MoneyUtils.fenToYuan(1, showSymbol: false), '0.01');
    });
  });
}
