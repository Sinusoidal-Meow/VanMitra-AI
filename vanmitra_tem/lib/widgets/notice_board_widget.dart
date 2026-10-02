import 'package:flutter/material.dart';
import '../models/notice.dart';
import '../core/theme/app_colors.dart';

enum NoticeBoardMode { ticker, fullList }

/// MAHA-DBT style Notice Board — two modes:
///
/// **ticker**: single-line scrolling banner (used in PortalFrameScaffold header)
/// **fullList**: expandable card per notice (used on home screens, per spec B.4.3)
class NoticeBoardWidget extends StatefulWidget {
  final List<Notice> notices;
  final NoticeBoardMode mode;
  final String lang;
  final void Function(String noticeId)? onDismiss;
  final void Function(Notice notice)? onTap;

  const NoticeBoardWidget({
    super.key,
    required this.notices,
    required this.mode,
    required this.lang,
    this.onDismiss,
    this.onTap,
  });

  @override
  State<NoticeBoardWidget> createState() => _NoticeBoardWidgetState();
}

class _NoticeBoardWidgetState extends State<NoticeBoardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  int _currentIndex = 0;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.mode == NoticeBoardMode.ticker && widget.notices.length > 1) {
      _ticker = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _currentIndex =
                  (_currentIndex + 1) % widget.notices.length;
            });
            _ticker.forward(from: 0);
          }
        })
        ..forward();
    } else {
      _ticker = AnimationController(vsync: this);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Color _severityColor(NoticeSeverity s) {
    switch (s) {
      case NoticeSeverity.critical:
        return AppColors.alertRed;
      case NoticeSeverity.warning:
        return AppColors.warningAmber;
      case NoticeSeverity.info:
        return AppColors.govtBlue;
    }
  }

  IconData _severityIcon(NoticeSeverity s) {
    switch (s) {
      case NoticeSeverity.critical:
        return Icons.warning_amber_rounded;
      case NoticeSeverity.warning:
        return Icons.info_outline_rounded;
      case NoticeSeverity.info:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notices.isEmpty) return const SizedBox.shrink();

    if (widget.mode == NoticeBoardMode.ticker) {
      return _buildTicker();
    }
    return _buildFullList();
  }

  // ── Ticker mode ─────────────────────────────────────────────────────────────

  Widget _buildTicker() {
    final notice = widget.notices[_currentIndex];
    final color = _severityColor(notice.severity);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.3)),
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: InkWell(
        onTap: () => widget.onTap?.call(notice),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(_severityIcon(notice.severity), color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${notice.titleFor(widget.lang)}: ${notice.bodyFor(widget.lang)}',
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.notices.length > 1)
                Text(
                  '${_currentIndex + 1}/${widget.notices.length}',
                  style: TextStyle(fontSize: 9, color: color),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => widget.onDismiss?.call(notice.noticeId),
                child: Icon(Icons.close, color: color, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Full list mode ──────────────────────────────────────────────────────────

  Widget _buildFullList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded,
                  color: AppColors.govtBlue, size: 18),
              const SizedBox(width: 8),
              const Text(
                'सूचना फलक',
                style: TextStyle(
                  fontFamily: 'NotoSansDevanagari',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.govtBlue,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSaffron.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accentSaffron.withOpacity(0.3)),
                ),
                child: Text(
                  '${widget.notices.length} सूचना',
                  style: const TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 10,
                    color: AppColors.accentSaffron,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...widget.notices.map((notice) => _buildNoticeCard(notice)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNoticeCard(Notice notice) {
    final c = context.colors;
    final color = _severityColor(notice.severity);
    final isExpanded = _expandedIds.contains(notice.noticeId);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedIds.remove(notice.noticeId);
                } else {
                  _expandedIds.add(notice.noticeId);
                }
              });
              widget.onTap?.call(notice);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(_severityIcon(notice.severity),
                        color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.titleFor(widget.lang),
                          style: TextStyle(
                            fontFamily: 'NotoSansDevanagari',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notice.category.displayNameMr,
                          style: TextStyle(
                            fontFamily: 'NotoSansDevanagari',
                            fontSize: 10,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (notice.source == NoticeSource.systemGenerated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.govtBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'स्वयंचलित',
                            style: TextStyle(
                                fontSize: 9, color: AppColors.govtBlue),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: c.textTertiary,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.04),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: c.border),
                  const SizedBox(height: 8),
                  Text(
                    notice.bodyFor(widget.lang),
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'वैध: ${_formatDate(notice.validUntil)} पर्यंत',
                        style: TextStyle(
                          fontSize: 10,
                          color: c.textTertiary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            widget.onDismiss?.call(notice.noticeId),
                        child: const Text(
                          'बंद करा',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.govtBlue,
                            fontWeight: FontWeight.w600,
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
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
