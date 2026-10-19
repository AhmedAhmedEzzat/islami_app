import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/services/names_learning.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/utils/l10n_ext.dart';
import 'names_view.dart';

/// Learning the 99 Names: flashcards, and a short quiz.
class NamesLearnView extends StatelessWidget {
  const NamesLearnView({super.key, this.random, this.preloaded});

  /// For tests; otherwise a fresh shuffle each time.
  final Random? random;

  /// The names, when already loaded (tests); otherwise read from the assets.
  final List<AllahName>? preloaded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.namesLearnTitle),
          bottom: TabBar(tabs: [Tab(text: l10n.namesCards), Tab(text: l10n.namesQuiz)]),
        ),
        body: FutureBuilder<List<AllahName>>(
          future: preloaded == null ? AllahName.load() : null,
          initialData: preloaded,
          builder: (context, snap) {
            final names = snap.data;
            if (names == null) return const Center(child: CircularProgressIndicator());
            final rng = random ?? Random();
            return TabBarView(
              children: [
                _Cards(names: names, random: rng),
                _Quiz(names: names, random: rng),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Arabic readers learn the names in order (the meanings come in English
/// only); others learn what each means.
bool _byOrder(BuildContext context) => context.isArabic;

String _number(BuildContext context, int n) => context.isArabic ? ArabicText.digits(n) : '$n';

Widget _arabicName(BuildContext context, String text, {double size = 40}) => Text(
  text,
  textDirection: TextDirection.rtl,
  textAlign: TextAlign.center,
  style: TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 1.6, color: context.colors.primary),
);

class _Cards extends StatefulWidget {
  const _Cards({required this.names, required this.random});

  final List<AllahName> names;
  final Random random;

  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  late List<int> _order = NamesLearning.cardOrder(widget.names.length, NamesLearning.learned(), widget.random);
  int _at = 0;
  bool _flipped = false;

  void _next({required bool knew}) {
    final name = widget.names[_order[_at]];
    NamesLearning.setLearned(name.number, knew);
    setState(() {
      _flipped = false;
      _at = (_at + 1) % _order.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final name = widget.names[_order[_at]];
    final byOrder = _byOrder(context);
    return ValueListenableBuilder<int>(
      valueListenable: NamesLearning.changes,
      builder: (context, _, _) {
        final learnt = NamesLearning.learned().length;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.namesLearned(learnt, widget.names.length), style: context.texts.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(value: learnt / widget.names.length, minHeight: 6),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              button: true,
              label: l10n.namesTapToFlip,
              child: InkWell(
                borderRadius: AppRadius.cardRadius,
                onTap: () => setState(() => _flipped = !_flipped),
                child: Card(
                  color: _flipped ? scheme.primaryContainer : scheme.surfaceContainer,
                  child: SizedBox(
                    height: 260,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey('$_at-$_flipped'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: !_flipped
                              ? [
                                  if (byOrder) ...[
                                    Text(l10n.namesWhichIs(_number(context, name.number)), style: context.texts.titleLarge, textAlign: TextAlign.center),
                                  ] else
                                    _arabicName(context, name.arabic),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    l10n.namesTapToFlip,
                                    style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ]
                              : [
                                  Text(_number(context, name.number), style: context.texts.labelLarge?.copyWith(color: scheme.primary)),
                                  _arabicName(context, name.arabic, size: byOrder ? 40 : 30),
                                  Text(name.transliteration, style: context.texts.titleMedium, textAlign: TextAlign.center),
                                  if (!byOrder) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(name.meaning, style: context.texts.bodyLarge, textAlign: TextAlign.center),
                                  ],
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _next(knew: false),
                    icon: const Icon(Icons.replay),
                    label: Text(l10n.namesAgain),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _next(knew: true),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.namesKnowIt),
                  ),
                ),
              ],
            ),
            if (learnt > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await NamesLearning.reset();
                    setState(() {
                      _order = NamesLearning.cardOrder(widget.names.length, {}, widget.random);
                      _at = 0;
                      _flipped = false;
                    });
                  },
                  child: Text(l10n.namesStartOver),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Quiz extends StatefulWidget {
  const _Quiz({required this.names, required this.random});

  final List<AllahName> names;
  final Random random;

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  List<NameQuestion>? _questions;
  int _at = 0;
  int _score = 0;
  int? _picked;

  void _start(NameQuizKind kind) => setState(() {
    _questions = NamesLearning.quiz(widget.names.length, kind, widget.random);
    _at = 0;
    _score = 0;
    _picked = null;
  });

  void _pick(int choice) {
    if (_picked != null) return;
    final q = _questions![_at];
    setState(() {
      _picked = choice;
      if (choice == q.answer) _score++;
    });
    // Getting it right counts as knowing the name asked about.
    if (choice == q.answer) NamesLearning.setLearned(widget.names[q.prompt].number, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final kind = _byOrder(context) ? NameQuizKind.next : NameQuizKind.meaning;
    final questions = _questions;

    if (questions == null || _at >= questions.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(questions == null ? Icons.quiz_outlined : Icons.emoji_events_outlined, size: 56, color: scheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                questions == null
                    ? (kind == NameQuizKind.next ? l10n.namesQuizIntroOrder : l10n.namesQuizIntroMeaning)
                    : l10n.namesQuizScore(_score, questions.length),
                textAlign: TextAlign.center,
                style: context.texts.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => _start(kind),
                child: Text(questions == null ? l10n.namesQuizStart : l10n.namesQuizAgain),
              ),
            ],
          ),
        ),
      );
    }

    final q = questions[_at];
    final prompt = widget.names[q.prompt];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.namesQuizProgress(_at + 1, questions.length), style: context.texts.labelLarge),
        const SizedBox(height: AppSpacing.md),
        Text(
          kind == NameQuizKind.next ? l10n.namesQuizWhatNext : l10n.namesQuizWhatMeans,
          style: context.texts.titleMedium,
        ),
        _arabicName(context, prompt.arabic),
        const SizedBox(height: AppSpacing.md),
        for (final c in q.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _Choice(
              text: kind == NameQuizKind.next ? widget.names[c].arabic : widget.names[c].meaning,
              arabic: kind == NameQuizKind.next,
              state: _picked == null
                  ? null
                  : c == q.answer
                  ? true
                  : c == _picked
                  ? false
                  : null,
              onTap: () => _pick(c),
            ),
          ),
        if (_picked != null)
          FilledButton(
            onPressed: () => setState(() {
              _at++;
              _picked = null;
            }),
            child: Text(_at + 1 == questions.length ? l10n.namesQuizFinish : l10n.namesQuizNext),
          ),
      ],
    );
  }
}

/// One answer; [state] is true for the right one and false for a wrong pick
/// once answered.
class _Choice extends StatelessWidget {
  const _Choice({required this.text, required this.arabic, required this.state, required this.onTap});

  final String text;
  final bool arabic;
  final bool? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = switch (state) {
      true => Colors.green.withValues(alpha: 0.25),
      false => scheme.errorContainer,
      null => scheme.surfaceContainer,
    };
    return Material(
      color: color,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: arabic
                    ? Text(text, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 22, height: 1.6))
                    : Text(text, style: context.texts.bodyLarge),
              ),
              if (state != null) Icon(state! ? Icons.check_circle : Icons.cancel, color: state! ? Colors.green : scheme.error),
            ],
          ),
        ),
      ),
    );
  }
}
