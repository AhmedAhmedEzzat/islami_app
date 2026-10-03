import 'package:flutter/foundation.dart';

@immutable
class ZakatInput {
  const ZakatInput({
    this.cash = 0,
    this.goldGrams = 0,
    this.goldPrice = 0,
    this.silverGrams = 0,
    this.silverPrice = 0,
    this.business = 0,
    this.receivable = 0,
    this.debts = 0,
    this.nisabOnGold = true,
  });

  final double cash;
  final double goldGrams;

  /// Price per gram, in the same currency as every other amount.
  final double goldPrice;
  final double silverGrams;
  final double silverPrice;

  /// Trade goods at current market value.
  final double business;

  /// Money owed to you that you expect to be repaid.
  final double receivable;

  /// Debts you must pay now; deducted before comparing with the nisab.
  final double debts;

  /// Nisab measured against 85 g of gold, or else 595 g of silver.
  final bool nisabOnGold;
}

@immutable
class ZakatResult {
  const ZakatResult({required this.netWealth, required this.nisab, required this.due});

  final double netWealth;

  /// Null when the metal price it depends on has not been entered.
  final double? nisab;

  final double due;

  bool get aboveNisab => nisab != null && netWealth >= nisab!;
}

/// The standard calculation: 2.5% of zakatable wealth, once it reaches the
/// nisab. Currency-agnostic — every amount is in the user's own currency.
abstract final class ZakatCalculator {
  static const double goldNisabGrams = 85;
  static const double silverNisabGrams = 595;
  static const double rate = 0.025;

  static ZakatResult compute(ZakatInput i) {
    double pos(double v) => v.isFinite && v > 0 ? v : 0;

    final assets =
        pos(i.cash) +
        pos(i.goldGrams) * pos(i.goldPrice) +
        pos(i.silverGrams) * pos(i.silverPrice) +
        pos(i.business) +
        pos(i.receivable);
    final net = (assets - pos(i.debts)).clamp(0.0, double.infinity);

    final price = i.nisabOnGold ? pos(i.goldPrice) : pos(i.silverPrice);
    final nisab = price == 0
        ? null
        : price * (i.nisabOnGold ? goldNisabGrams : silverNisabGrams);

    final due = nisab != null && net >= nisab ? net * rate : 0.0;
    return ZakatResult(netWealth: net, nisab: nisab, due: due);
  }
}
