import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/routes/app_router.dart';
import '../../models/gram_sabha_meeting.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../widgets/common/app_components.dart';

/// Renovated Gram Sabha Governance Dashboard — displaying upcoming sessions and past legal meeting records
/// with Forest Canopy branding, StatusBadge tracking, and standardized EmptyStates.
class GramSabhaDashboard extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  const GramSabhaDashboard({super.key, this.bottomNavigationBar});

  @override
  ConsumerState<GramSabhaDashboard> createState() => _GramSabhaDashboardState();
}

class _GramSabhaDashboardState extends ConsumerState<GramSabhaDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetingsState = ref.watch(meetingsProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.currentUser?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: AppColors.textOnBrand,
        elevation: 2,
        title: Text('ग्रामसभा | Gram Sabha Records', style: AppTypography.title.copyWith(color: AppColors.textOnBrand, fontSize: 18)),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.saffron,
          indicatorWeight: 3.5,
          labelColor: AppColors.textOnBrand,
          unselectedLabelColor: AppColors.forestMist,
          labelStyle: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Upcoming (येणारी बैठक)'),
            Tab(text: 'Past (मागील नोंदी)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMeetingList(meetingsState.upcomingMeetings, meetingsState.todayMeeting, isAdmin: isAdmin),
          _buildMeetingList(meetingsState.pastMeetings, null, isAdmin: isAdmin, isPast: true),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isAdmin
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: PrimaryButton(
                label: 'Schedule New Gram Sabha',
                icon: Icons.add_circle_outline_rounded,
                onPressed: () => Navigator.pushNamed(context, AppRouter.createMeeting),
              ),
            )
          : null,
    );
  }

  Widget _buildMeetingList(List<GramSabhaMeeting> meetings, GramSabhaMeeting? todayMeeting, {required bool isAdmin, bool isPast = false}) {
    final c = context.colors;
    final allMeetings = [...meetings];
    if (todayMeeting != null && !allMeetings.any((m) => m.id == todayMeeting.id)) {
      allMeetings.insert(0, todayMeeting);
    }

    if (allMeetings.isEmpty) {
      return EmptyState(
        icon: isPast ? Icons.folder_shared_outlined : Icons.event_note_rounded,
        title: isPast ? 'No completed meeting archives found.' : 'No meetings scheduled yet.',
        description: isPast
            ? 'Completed Gram Sabha agendas and resolution ledgers will be permanently preserved here.'
            : 'Check back for official session schedules or initiate a meeting as FRC Admin.',
        ctaLabel: (!isPast && isAdmin) ? 'Schedule Meeting' : null,
        onCtaPressed: (!isPast && isAdmin) ? () => Navigator.pushNamed(context, AppRouter.createMeeting) : null,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 100, left: AppSpacing.md, right: AppSpacing.md),
      itemCount: allMeetings.length,
      itemBuilder: (context, index) {
        final meeting = allMeetings[index];
        final isToday = meeting.id == todayMeeting?.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            elevation: isToday ? AppElevation.raised : AppElevation.floating,
            borderColor: isToday ? AppColors.saffron : (c.isDark ? c.border : AppColors.divider),
            onTap: () => Navigator.pushNamed(context, AppRouter.meetingDetail, arguments: meeting.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        meeting.type.displayNameMr,
                        style: AppTypography.title.copyWith(fontSize: 16, color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(
                      label: isToday ? 'TODAY ACTIVE' : meeting.status.name.toUpperCase(),
                      status: _toStatusType(meeting.status, isToday: isToday),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 15, color: c.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(meeting.scheduledDate),
                      style: AppTypography.body.copyWith(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 15, color: AppColors.forestSage),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        meeting.venue,
                        style: AppTypography.body.copyWith(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isToday) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Tap to access attendance quorum & agenda ›',
                        style: AppTypography.caption.copyWith(color: AppColors.saffron, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  StatusType _toStatusType(MeetingStatus status, {bool isToday = false}) {
    if (isToday) return StatusType.verified;
    switch (status) {
      case MeetingStatus.scheduled:
        return StatusType.pending;
      case MeetingStatus.inProgress:
      case MeetingStatus.completed:
        return StatusType.verified;
      case MeetingStatus.cancelled:
        return StatusType.error;
    }
  }
}
