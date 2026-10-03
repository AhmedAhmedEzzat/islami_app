import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/l10n_ext.dart';
import '../../../../core/widgets/sakina_mark.dart';

/// Renders a verse onto a designed card and shares it as a PNG, the way
/// people post verses to social media.
abstract final class VerseImageShare {
  static Future<void> share(
    BuildContext context, {
    required String text,
    required String citation,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PreviewDialog(text: text, citation: citation),
    );
  }
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({required this.text, required this.citation});

  final String text;
  final String citation;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  final GlobalKey _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final render =
          _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 3x so the image is crisp when posted.
      final image = await render.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sakina_verse.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: widget.citation),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _boundary,
              child: _VerseCard(text: widget.text, citation: widget.citation),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share),
                  label: Text(context.l10n.shareVerse),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The shareable card. Fixed colours rather than theme colours, so the image
/// looks the same whichever mode the sender's phone is in.
class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.text, required this.citation});

  final String text;
  final String citation;

  static const Color _green = Color(0xFF1B5E20);
  static const Color _paper = Color(0xFFF1F8E9);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _green, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 22,
              height: 2.0,
              color: Color(0xFF1B3B1E),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            citation,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Janna',
              fontSize: 13,
              color: _green,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: SakinaMark(color: _green)),
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Sakina · سكينة',
                style: TextStyle(fontFamily: 'Janna', fontSize: 11, color: _green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
