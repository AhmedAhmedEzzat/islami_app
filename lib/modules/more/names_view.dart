import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

class AllahName {
  const AllahName(this.number, this.arabic, this.transliteration, this.meaning);

  final int number;
  final String arabic;
  final String transliteration;
  final String meaning;

  static Future<List<AllahName>>? _cache;

  /// Loaded once; the screen's FutureBuilder asks again on every rebuild.
  static Future<List<AllahName>> load() => _cache ??= _load();

  static Future<List<AllahName>> _load() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/names/asma.json'),
    );
    return [
      for (final n in (json as Map<String, dynamic>)['names'] as List)
        AllahName(
          n['n'] as int,
          n['ar'] as String,
          n['tr'] as String,
          n['en'] as String,
        ),
    ];
  }
}

/// The 99 Names, with transliteration and meaning.
class NamesView extends StatelessWidget {
  const NamesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.namesTitle)),
      body: FutureBuilder<List<AllahName>>(
        future: AllahName.load(),
        builder: (context, snap) {
          final names = snap.data;
          if (names == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.05,
            ),
            itemCount: names.length + 1,
            itemBuilder: (context, i) {
              if (i == names.length) {
                return Center(
                  child: Text(
                    context.l10n.namesSource,
                    textAlign: TextAlign.center,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return _NameCard(name: names[i]);
            },
          );
        },
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({required this.name});

  final AllahName name;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${name.number}',
              style: context.texts.labelSmall?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 26,
                height: 1.6,
                color: scheme.primary,
              ),
            ),
            Text(
              name.transliteration,
              textAlign: TextAlign.center,
              style: context.texts.labelMedium,
            ),
            // The meanings come in English only; in Arabic the name speaks for
            // itself.
            if (!context.isArabic)
              Text(
                name.meaning,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
