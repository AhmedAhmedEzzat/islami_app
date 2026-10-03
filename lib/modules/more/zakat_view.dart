import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/constants/prefs_keys.dart';
import '../../core/services/shared_prefs_helper.dart';
import '../../core/services/zakat_calculator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

/// Works out zakat on cash, gold, silver, trade goods and receivables.
class ZakatView extends StatefulWidget {
  const ZakatView({super.key});

  @override
  State<ZakatView> createState() => _ZakatViewState();
}

class _ZakatViewState extends State<ZakatView> {
  static const _fields = [
    'cash',
    'goldGrams',
    'goldPrice',
    'silverGrams',
    'silverPrice',
    'business',
    'receivable',
    'debts',
  ];

  late final Map<String, TextEditingController> _c = {
    for (final f in _fields) f: TextEditingController(),
  };
  bool _onGold = true;

  @override
  void initState() {
    super.initState();
    // Inputs are remembered: metal prices and savings change slowly, and
    // nobody wants to retype them every year.
    final raw = LocalStorageServices.getString(PrefsKeys.zakatInputs);
    if (raw != null) {
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        for (final f in _fields) {
          final v = saved[f];
          if (v is num && v != 0) _c[f]!.text = _trim(v.toDouble());
        }
        _onGold = saved['onGold'] as bool? ?? true;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double _v(String f) => double.tryParse(_c[f]!.text.replaceAll(',', '.')) ?? 0;

  ZakatInput get _input => ZakatInput(
    cash: _v('cash'),
    goldGrams: _v('goldGrams'),
    goldPrice: _v('goldPrice'),
    silverGrams: _v('silverGrams'),
    silverPrice: _v('silverPrice'),
    business: _v('business'),
    receivable: _v('receivable'),
    debts: _v('debts'),
    nisabOnGold: _onGold,
  );

  void _changed() {
    setState(() {});
    LocalStorageServices.setString(
      PrefsKeys.zakatInputs,
      jsonEncode({for (final f in _fields) f: _v(f), 'onGold': _onGold}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final result = ZakatCalculator.compute(_input);
    final money = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 2,
    );

    Widget field(String key, String label, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: _c[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => _changed(),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.zakatTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            color: result.aboveNisab
                ? scheme.primaryContainer
                : scheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.zakatDue, style: context.texts.labelLarge),
                  Text(
                    money.format(result.due),
                    style: context.texts.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Row(l10n.zakatNetWealth, money.format(result.netWealth)),
                  _Row(
                    l10n.zakatNisab,
                    result.nisab == null ? '—' : money.format(result.nisab),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (result.nisab == null)
                    Text(
                      l10n.zakatNeedPrice,
                      style: context.texts.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    )
                  else if (!result.aboveNisab)
                    Text(l10n.zakatBelowNisab, style: context.texts.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.zakatNisabBasis, style: context.texts.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.zakatNisabGold)),
              ButtonSegment(value: false, label: Text(l10n.zakatNisabSilver)),
            ],
            selected: {_onGold},
            onSelectionChanged: (s) {
              _onGold = s.first;
              _changed();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          field('cash', l10n.zakatCash, Icons.payments_outlined),
          field('goldGrams', l10n.zakatGoldGrams, Icons.circle),
          field('goldPrice', l10n.zakatGoldPrice, Icons.sell_outlined),
          field('silverGrams', l10n.zakatSilverGrams, Icons.circle_outlined),
          field('silverPrice', l10n.zakatSilverPrice, Icons.sell_outlined),
          field('business', l10n.zakatBusiness, Icons.storefront_outlined),
          field('receivable', l10n.zakatReceivable, Icons.call_received),
          field('debts', l10n.zakatDebts, Icons.call_made),
          Text(
            l10n.zakatHawlNote,
            style: context.texts.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: context.texts.bodyMedium)),
      Text(value, style: context.texts.titleSmall),
    ],
  );
}
