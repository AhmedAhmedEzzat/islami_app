import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/services/hadeth_favourites.dart';
import '../../../models/hadeth_data_model.dart';
import '../../../core/utils/l10n_ext.dart';

class HadethDetailsView extends StatelessWidget {
  const HadethDetailsView({super.key, required this.hadeth});

  final HadethDataModel hadeth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(hadeth.title, textDirection: TextDirection.rtl),
        actions: [
          ValueListenableBuilder<Set<int>>(
            valueListenable: HadethFavourites.notifier,
            builder: (context, favourites, _) {
              final fav = favourites.contains(hadeth.number);
              return IconButton(
                tooltip: fav ? context.l10n.removeFavourite : context.l10n.addFavourite,
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
                onPressed: () => HadethFavourites.toggle(hadeth.number),
              );
            },
          ),
          IconButton(
            tooltip: context.l10n.copyVerse,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: hadeth.fullText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.copied)),
              );
            },
          ),
          IconButton(
            tooltip: context.l10n.shareHadeth,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: '${hadeth.title}\n\n${hadeth.content.join('\n')}',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            hadeth.title,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: context.texts.headlineSmall?.copyWith(
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final paragraph in hadeth.content)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                paragraph,
                textAlign: TextAlign.justify,
                textDirection: TextDirection.rtl,
                style: context.texts.bodyLarge?.copyWith(
                  color: context.colors.onSurface,
                  height: 1.9,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
