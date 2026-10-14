import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/case_hub/case_hub_api.dart';
import '../features/case_hub/cases_list_screen.dart' show reviewQueueChanged;

/// For the Gram Sabha and the SDO: how many claims are waiting for their decision, one tap from
/// the list. Reloads whenever the claims lists were reloaded (after an approval, for example).
class ReviewQueueCard extends StatefulWidget {
  const ReviewQueueCard({super.key, required this.officeLabel, required this.onOpen});

  /// "Gram Sabha" or "SDO", for the wording.
  final String officeLabel;
  final VoidCallback onOpen;

  @override
  State<ReviewQueueCard> createState() => _ReviewQueueCardState();
}

class _ReviewQueueCardState extends State<ReviewQueueCard> {
  final CaseHubApi _api = CaseHubApi();
  int? _count;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    reviewQueueChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    reviewQueueChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final queue = await _api.getReviewQueue();
      if (!mounted) return;
      setState(() {
        _count = queue.length;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final waiting = count != null && count > 0;
    final text = _failed
        ? 'Could not load the claims waiting for you. Tap to open the list.'
        : count == null
            ? 'Checking for claims waiting for you...'
            : waiting
                ? '$count claim${count == 1 ? '' : 's'} waiting for your decision'
                : 'No claims are waiting for your decision';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onOpen,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: waiting ? AppColors.saffron.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: waiting ? AppColors.saffron : const Color(0xFFEEF2EF),
              width: waiting ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: waiting ? AppColors.saffron : const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.fact_check_rounded,
                  color: waiting ? Colors.white : const Color(0xFF2E705B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.officeLabel} review',
                      style: const TextStyle(
                        color: Color(0xFF143526),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}
