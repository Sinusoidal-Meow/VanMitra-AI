import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// DBT print-preview styled card for AI-generated drafts and appeals.
///
/// Looks like the printed Form A/B it will become — white background,
/// subtle page shadow, serif/monospace body font — distinct from the
/// rest of the app's UI chrome, per spec B.4.6.
///
/// When [isAIGenerated] is true, shows an amber "AI-Generated Draft"
/// review banner above the text. Human approval is always required.
class DocumentPaperCard extends StatefulWidget {
  final String draftText;
  final bool isAIGenerated;
  final String title;

  /// Called when user taps "मान्य आहे" (Approve)
  final VoidCallback? onApprove;

  /// Called when user taps "संपादित करा" (Edit)
  final VoidCallback? onEdit;

  /// If true, the text is rendered in an editable field
  final bool isEditMode;
  final TextEditingController? editController;

  const DocumentPaperCard({
    super.key,
    required this.draftText,
    required this.isAIGenerated,
    required this.title,
    this.onApprove,
    this.onEdit,
    this.isEditMode = false,
    this.editController,
  });

  @override
  State<DocumentPaperCard> createState() => _DocumentPaperCardState();
}

class _DocumentPaperCardState extends State<DocumentPaperCard> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── AI-Generated Banner ─────────────────────────────────────────────
        if (widget.isAIGenerated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.12),
              border: Border(
                left: BorderSide(color: AppColors.warningAmber, width: 4),
                bottom: BorderSide(
                    color: AppColors.warningAmber.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: AppColors.warningAmber, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI-Generated Draft — Please Review / AI-निर्मित मसुदा — कृपया तपासा',
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.govtBlue.withOpacity(0.06),
            child: const Text(
              'Template Draft — ऑफलाइन मसुदा (टेम्पलेट)',
              style: TextStyle(
                fontFamily: 'NotoSansDevanagari',
                fontSize: 11,
                color: AppColors.govtBlue,
              ),
            ),
          ),

        // ── Paper Card ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.cardBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              // Simulate paper stack / depth
              BoxShadow(
                color: context.colors.isDark ? Colors.black.withOpacity(0.4) : const Color(0x22000000),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
              BoxShadow(
                color: context.colors.isDark ? Colors.black.withOpacity(0.2) : const Color(0x11000000),
                blurRadius: 16,
                offset: const Offset(4, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document header stripe (saffron — matches FRA forms)
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.govtBlue,
                      AppColors.accentSaffron,
                      AppColors.successGreen,
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document title
                    Center(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'NotoSansDevanagari',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.govtBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Divider(thickness: 2, color: AppColors.govtBlue),
                    const SizedBox(height: 12),

                    // Draft text (view or edit mode)
                    if (widget.isEditMode && widget.editController != null)
                      TextFormField(
                        controller: widget.editController,
                        maxLines: null,
                        style: TextStyle(
                          fontFamily: 'NotoSansDevanagari',
                          fontSize: 13,
                          height: 1.7,
                          color: context.colors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      )
                    else
                      SelectableText(
                        widget.draftText,
                        style: TextStyle(
                          fontFamily: 'NotoSansDevanagari',
                          fontSize: 13,
                          height: 1.8,
                          color: context.colors.textPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Approve / Edit action row
                    Row(
                      children: [
                        // Edit button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'संपादित करा',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.govtBlue,
                              side: const BorderSide(
                                  color: AppColors.govtBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Approve button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onApprove,
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text(
                              'मान्य आहे',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
