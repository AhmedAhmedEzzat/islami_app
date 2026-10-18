import 'package:flutter/material.dart';

import '../../core/services/tafsir_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import '../more/listen_view.dart';

/// Saves both tafsirs for every sura so the verse sheet works offline, shows
/// how far along that is, and removes them again.
class TafsirDownloadTile extends StatelessWidget {
  const TafsirDownloadTile({super.key});

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await TafsirService.downloadAll();
    // Nothing to say when it was stopped on purpose.
    if (ok == null) return;
    messenger.showSnackBar(SnackBar(content: Text(ok ? l10n.offlineTafsirDone : l10n.offlineTafsirFailed)));
  }

  @override
  Widget build(BuildContext context) {
    if (!TafsirService.supported) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = context.colors;

    return ValueListenableBuilder<int>(
      valueListenable: TafsirService.changes,
      builder: (context, _, _) => FutureBuilder<int>(
        future: TafsirService.savedSuras(),
        builder: (context, snap) => ValueListenableBuilder<double?>(
          valueListenable: TafsirService.downloadProgress,
          builder: (context, progress, _) {
            final saved = snap.data ?? 0;
            final complete = saved == TafsirService.suraCount;
            return ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.offlineTafsir),
              subtitle: progress != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(value: progress, minHeight: 6),
                      ),
                    )
                  : Text(
                      complete
                          ? l10n.offlineTafsirAll
                          : l10n.offlineTafsirSaved(saved, TafsirService.suraCount),
                    ),
              trailing: progress != null
                  ? IconButton(
                      tooltip: l10n.stopDownloads,
                      icon: const Icon(Icons.stop_rounded),
                      onPressed: TafsirService.cancel,
                    )
                  : complete
                  ? IconButton(
                      tooltip: l10n.delete,
                      icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
                      onPressed: () async {
                        if (await confirmDelete(context, l10n.deleteTafsirConfirm)) {
                          await TafsirService.deleteAll();
                        }
                      },
                    )
                  : IconButton(
                      tooltip: l10n.download,
                      icon: Icon(Icons.download_rounded, color: scheme.primary),
                      onPressed: () => _download(context),
                    ),
            );
          },
        ),
      ),
    );
  }
}
