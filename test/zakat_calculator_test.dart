import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/zakat_calculator.dart';

void main() {
  ZakatResult calc(ZakatInput i) => ZakatCalculator.compute(i);

  test('2.5% of wealth at or above the nisab', () {
    final r = calc(const ZakatInput(cash: 10000, goldPrice: 100));
    expect(r.nisab, 8500); // 85 g x 100
    expect(r.aboveNisab, isTrue);
    expect(r.due, closeTo(250, 1e-9));
  });

  test('exactly the nisab is liable', () {
    final r = calc(const ZakatInput(cash: 8500, goldPrice: 100));
    expect(r.due, closeTo(212.5, 1e-9));
  });

  test('below the nisab nothing is due', () {
    final r = calc(const ZakatInput(cash: 8499, goldPrice: 100));
    expect(r.aboveNisab, isFalse);
    expect(r.due, 0);
  });

  test('debts are deducted before the nisab test', () {
    final r = calc(const ZakatInput(cash: 10000, debts: 2000, goldPrice: 100));
    expect(r.netWealth, 8000);
    expect(r.due, 0);
  });

  test('gold, silver, trade goods and receivables all count', () {
    final r = calc(
      const ZakatInput(
        goldGrams: 10,
        goldPrice: 100,
        silverGrams: 100,
        silverPrice: 1,
        business: 500,
        receivable: 400,
        nisabOnGold: false,
      ),
    );
    expect(r.netWealth, 1000 + 100 + 500 + 400);
    expect(r.nisab, 595); // silver nisab, 595 g x 1
    expect(r.due, closeTo(50, 1e-9));
  });

  test('no nisab without the metal price it is based on', () {
    final r = calc(const ZakatInput(cash: 1e6, nisabOnGold: true, silverPrice: 1));
    expect(r.nisab, isNull);
    expect(r.due, 0);
  });

  test('negative or invalid amounts are treated as zero', () {
    final r = calc(const ZakatInput(cash: -500, goldPrice: double.nan, debts: -10));
    expect(r.netWealth, 0);
    expect(r.nisab, isNull);
  });

  test('debts larger than assets leave zero, not negative wealth', () {
    expect(calc(const ZakatInput(cash: 100, debts: 500, goldPrice: 1)).netWealth, 0);
  });
}
