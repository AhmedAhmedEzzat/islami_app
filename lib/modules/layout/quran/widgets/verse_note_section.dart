import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/quran_meta.dart';
import '../../../../core/state/verse_notes_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/l10n_ext.dart';
import '../../../../core/widgets/text_prompt_dialog.dart';

/// The verse sheet's own corner: a highlighter colour and a personal note.
class VerseNoteSection extends StatelessWidget {
  const VerseNoteSection({super.key, required this.verse, required this.title});

  final VerseRef verse;

  /// The section heading, styled like the sheet's others.
  final Widget title;

  Future<void> _edit(BuildContext context, String current) async {
    final cubit = context.read<VerseNotesCubit>();
    final l10n = context.l10n;
    final text = await showTextPrompt(
      context,
      title: l10n.myNote,
      confirm: l10n.saveNote,
      hint: l10n.noteHint,
      initialText: current,
      multiline: true,
      maxLength: 2000,
    );
    if (text != null) await cubit.setText(verse, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final note = context.select<VerseNotesCubit, VerseNote?>((c) => c.noteFor(verse));
    final text = note?.text ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in HighlightColor.values)
              _Swatch(
                color: c.color,
                selected: note?.color == c,
                label: l10n.highlightIn(_colorName(context, c)),
                // Tapping the chosen colour again takes the highlight off.
                onTap: () => context.read<VerseNotesCubit>().setColor(verse, note?.color == c ? null : c),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (text.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _edit(context, ''),
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.addNote),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainer,
            child: InkWell(
              borderRadius: AppRadius.cardRadius,
              onTap: () => _edit(context, text),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(text, style: context.texts.bodyMedium)),
                    IconButton(
                      tooltip: l10n.deleteNote,
                      icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
                      onPressed: () => context.read<VerseNotesCubit>().setText(verse, ''),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _colorName(BuildContext context, HighlightColor c) {
  final l10n = context.l10n;
  return switch (c) {
    HighlightColor.yellow => l10n.colorYellow,
    HighlightColor.green => l10n.colorGreen,
    HighlightColor.blue => l10n.colorBlue,
    HighlightColor.pink => l10n.colorPink,
    HighlightColor.purple => l10n.colorPurple,
  };
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.label, required this.onTap});

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? context.colors.onSurface : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected ? const Icon(Icons.check, size: 20, color: Colors.black87) : null,
          ),
        ),
      ),
    );
  }
}
