import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../models/claim.dart';
import '../../config/ai_agent_config.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../services/localization_service.dart';

/// Claim Type Selection — Step 0 before the 5-step form.
///
/// Two large segmented cards (Form A / Form B), Marathi-first.
/// Also runs the FDST/OTFD eligibility pre-check from AiAgentConfig.
class ClaimTypeSelectionScreen extends ConsumerWidget {
  const ClaimTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(aiAgentConfigProvider);

    return PortalFrameScaffold(
      breadcrumbs: [context.tr('tab_dashboard'), context.tr('claims'), context.tr('claim_type')],
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Config error: $e')),
        data: (config) => _ClaimTypeBody(config: config),
      ),
    );
  }
}

class _ClaimTypeBody extends StatefulWidget {
  final AiAgentConfig config;
  const _ClaimTypeBody({required this.config});

  @override
  State<_ClaimTypeBody> createState() => _ClaimTypeBodyState();
}

class _ClaimTypeBodyState extends State<_ClaimTypeBody> {
  bool? _isScheduledTribe;
  String? _residenceStart;

  bool get _isEligible {
    if (_isScheduledTribe == null || _residenceStart == null) return false;
    try {
      final startDate = DateTime.parse(_residenceStart!);
      return startDate.isBefore(widget.config.fdstOtfdCutoffDate);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Eligibility Pre-check ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.isDark ? c.cardBg : AppColors.govtBlue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: c.isDark ? c.border : AppColors.govtBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('eligibility_check'),
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: c.isDark ? c.textPrimary : AppColors.govtBlue,
                  ),
                ),
                const SizedBox(height: 12),

                // Scheduled Tribe toggle
                Text(
                  context.tr('st_question'),
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 13,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _EligibilityToggle(
                      label: context.tr('yes'),
                      selected: _isScheduledTribe == true,
                      onTap: () =>
                          setState(() => _isScheduledTribe = true),
                    ),
                    const SizedBox(width: 12),
                    _EligibilityToggle(
                      label: context.tr('no'),
                      selected: _isScheduledTribe == false,
                      onTap: () =>
                          setState(() => _isScheduledTribe = false),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Residence start date
                Text(
                  context.tr('residence_year'),
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 13,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: context.tr('date_hint'),
                    hintStyle: TextStyle(fontSize: 12, color: c.textTertiary),
                    filled: c.isDark,
                    fillColor: c.isDark ? c.sunkenBg : null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: AppColors.accentSaffron, width: 1.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: c.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) =>
                      setState(() => _residenceStart = v.trim()),
                ),

                const SizedBox(height: 12),

                // Eligibility result
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isScheduledTribe == null || _residenceStart == null
                        ? Colors.transparent
                        : _isEligible
                            ? AppColors.successGreen.withOpacity(0.12)
                            : AppColors.alertRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: _isScheduledTribe != null && _residenceStart != null
                        ? Border.all(
                            color: _isEligible
                                ? AppColors.successGreen.withOpacity(0.4)
                                : AppColors.alertRed.withOpacity(0.4),
                          )
                        : null,
                  ),
                  child: _isScheduledTribe != null && _residenceStart != null
                      ? Text(
                          _isEligible
                              ? (_isScheduledTribe! ? context.tr('eligible_fdst') : context.tr('eligible_otfd'))
                              : context.tr('not_eligible'),
                          style: TextStyle(
                            fontFamily: 'NotoSansDevanagari',
                            fontSize: 12,
                            color: _isEligible
                                ? (c.isDark ? const Color(0xFF4ADE80) : AppColors.successGreen)
                                : (c.isDark ? const Color(0xFFF87171) : AppColors.alertRed),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            context.tr('select_claim_type'),
            style: TextStyle(
              fontFamily: 'NotoSansDevanagari',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('select_claim_type_sub'),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Form A Card ────────────────────────────────────────────────────
          _FormTypeCard(
            formKey: 'A',
            titleMr: widget.config.getFormTitle('A', 'mr'),
            titleEn: widget.config.getFormTitle('A', 'en'),
            description: context.tr('form_a_desc'),
            iconEmoji: '🏡',
            isRecommended: _isScheduledTribe == true,
            onSelect: () => Navigator.pushNamed(
              context,
              AppRouter.claimForm,
              arguments: ClaimType.formA,
            ),
          ),

          const SizedBox(height: 12),

          // ── Form B Card ────────────────────────────────────────────────────
          _FormTypeCard(
            formKey: 'B',
            titleMr: widget.config.getFormTitle('B', 'mr'),
            titleEn: widget.config.getFormTitle('B', 'en'),
            description: context.tr('form_b_desc'),
            iconEmoji: '🌳',
            isRecommended: false,
            onSelect: () => Navigator.pushNamed(
              context,
              AppRouter.claimForm,
              arguments: ClaimType.formB,
            ),
          ),

          const SizedBox(height: 24),

          // FRA reference link
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.isDark ? c.cardBg : AppColors.govtBlue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: c.isDark ? c.border : AppColors.govtBlue.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('fra_info'),
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 11,
                      color: c.isDark ? c.textPrimary : AppColors.govtBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibilityToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _EligibilityToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeBg = c.isDark ? AppColors.accentSaffron : AppColors.govtBlue;
    final inactiveBg = c.isDark ? c.cardBg : Colors.white;
    final inactiveBorder = c.isDark ? c.border : const Color(0xFFCBD5E1);
    final inactiveTextColor = c.isDark ? c.textPrimary : const Color(0xFF374151);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? activeBg : inactiveBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : inactiveTextColor,
          ),
        ),
      ),
    );
  }
}

class _FormTypeCard extends StatefulWidget {
  final String formKey;
  final String titleMr;
  final String titleEn;
  final String description;
  final String iconEmoji;
  final bool isRecommended;
  final VoidCallback onSelect;

  const _FormTypeCard({
    required this.formKey,
    required this.titleMr,
    required this.titleEn,
    required this.description,
    required this.iconEmoji,
    required this.isRecommended,
    required this.onSelect,
  });

  @override
  State<_FormTypeCard> createState() => _FormTypeCardState();
}

class _FormTypeCardState extends State<_FormTypeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onSelect();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isRecommended
                  ? AppColors.accentSaffron
                  : c.border,
              width: widget.isRecommended ? 2 : 1,
            ),
            boxShadow: c.isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.govtBlue.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.isDark
                      ? AppColors.forestDeep.withOpacity(0.6)
                      : AppColors.govtBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(widget.iconEmoji,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isRecommended)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSaffron.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.tr('recommended'),
                          style: const TextStyle(
                            fontFamily: 'NotoSansDevanagari',
                            fontSize: 10,
                            color: AppColors.accentSaffron,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      widget.titleMr,
                      style: TextStyle(
                        fontFamily: 'NotoSansDevanagari',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.isDark ? c.textPrimary : AppColors.govtBlue,
                      ),
                    ),
                    Text(
                      widget.titleEn,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontFamily: 'NotoSansDevanagari',
                        fontSize: 11,
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
