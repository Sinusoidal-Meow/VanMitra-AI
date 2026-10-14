import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/ask.dart';
import '../models/report.dart';
import '../providers/ask_providers.dart';
import '../widgets/answer_card.dart';
import '../widgets/lv_scaffold.dart';

/// "Ask about your report" (Module 4 PDF §11). He types a question or taps a suggestion; the
/// server checks it for harm FIRST, answers only from his own report, and checks every number
/// before it is shown. This screen only displays what it is told.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _maxChars = 500;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(askProvider.notifier).load());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  Future<void> _send({String? question, String? chip}) async {
    final ok = await ref
        .read(askProvider.notifier)
        .send(question: question, chip: chip, lang: _lang);
    if (ok && question != null) _input.clear();
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _send(question: text);
  }

  Future<void> _confirmClear(LivelihoodStrings s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('ask.clear_title')),
        content: Text(s.t('ask.clear_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('lv_keep')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('ask.clear_confirm')),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(askProvider.notifier).clear();
      if (mounted && ref.read(askProvider).errorKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('ask.cleared'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final state = ref.watch(askProvider);

    return LvScaffold(
      title: s.t('ask.title'),
      showAsk: false,
      actions: [
        IconButton(
          tooltip: s.t('ask.clear'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: state.turns.isEmpty ? null : () => _confirmClear(s),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: state.loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.saffron),
                  )
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      if (state.turns.isEmpty) _Intro(s.t('ask.intro')),
                      if (state.aiAvailable && state.aiConsent == null)
                        _ConsentCard(
                          title: s.t('ask.ai_consent_title'),
                          body: s.t('ask.ai_consent_body'),
                          allow: s.t('ask.ai_allow'),
                          deny: s.t('ask.ai_deny'),
                          onAllow: () =>
                              ref.read(askProvider.notifier).setAiConsent(true),
                          onDeny: () => ref
                              .read(askProvider.notifier)
                              .setAiConsent(false),
                        ),
                      for (final turn in state.turns) ...[
                        QuestionBubble(_questionText(s, turn)),
                        const SizedBox(height: AppSpacing.sm),
                        AnswerCard(turn.answer),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (state.busy)
                        _Thinking(s.t('ask.thinking'), c.textSecondary),
                      if (state.errorKey != null)
                        _ErrorLine(s.t(state.errorKey!)),
                    ],
                  ),
          ),
          if (state.aiAvailable && state.aiConsent != null)
            SwitchListTile(
              dense: true,
              value: state.aiConsent == true,
              onChanged: (v) => ref.read(askProvider.notifier).setAiConsent(v),
              title: Text(
                s.t('ask.ai_toggle'),
                style: AppTypography.caption.copyWith(color: c.textSecondary),
              ),
            ),
          if (state.chips.isNotEmpty)
            _Suggestions(
              label: s.t('ask.suggestions'),
              chips: state.chips,
              enabled: !state.busy,
              onTap: (chip) => _send(chip: chip.id),
            ),
          _InputBar(
            controller: _input,
            hint: s.t('ask.hint'),
            sendLabel: s.t('ask.send'),
            maxChars: _maxChars,
            enabled: !state.busy,
            onSend: _submit,
          ),
        ],
      ),
    );
  }

  /// What he typed, or for a tapped suggestion the suggestion's wording in the current language.
  String _questionText(LivelihoodStrings s, ChatTurn turn) {
    final typed = turn.question;
    if (typed != null && typed.isNotEmpty) return typed;
    final id = turn.chip ?? '';
    // a refused question is deliberately not kept by the server
    if (id.isEmpty) return s.t('ask.question_not_kept');
    final base = id.split(':').first;
    final params = base == 'idea'
        ? Map<String, dynamic>.from(turn.answer.headline.params)
        : const <String, dynamic>{};
    return s.reason(Reason('ask.chip.$base', params));
  }
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.forum_outlined, color: AppColors.forestSage),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asked once, plainly: may an AI assistant read the facts of his report (never his name or the
/// place of his plot)? Nothing is sent to it until he says yes.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.title,
    required this.body,
    required this.allow,
    required this.deny,
    required this.onAllow,
    required this.onDeny,
  });

  final String title;
  final String body;
  final String allow;
  final String deny;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.forestSage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: AppColors.forestSage),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTypography.body.copyWith(color: c.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: onAllow,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestSage,
                  minimumSize: const Size(120, 48),
                ),
                child: Text(allow),
              ),
              OutlinedButton(
                onPressed: onDeny,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                ),
                child: Text(deny),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.saffron,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTypography.body.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// A calm line for a problem (no internet, signed out ...), never a raw error code.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.sunkenBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 20, color: c.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body.copyWith(color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.label,
    required this.chips,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final List<SuggestedQuestion> chips;
  final bool enabled;
  final void Function(SuggestedQuestion) onTap;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final chip = chips[i];
                return ActionChip(
                  label: Text(s.reason(chip.label)),
                  labelStyle:
                      AppTypography.labelMedium.copyWith(color: c.textPrimary),
                  backgroundColor: c.chipUnselectedBg,
                  side: BorderSide(color: c.chipUnselectedBorder),
                  onPressed: enabled ? () => onTap(chip) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.maxChars,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final int maxChars;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                maxLength: maxChars,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  filled: true,
                  fillColor: c.sunkenBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: c.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              tooltip: sendLabel,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.forestSage,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded),
              onPressed: enabled ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}
