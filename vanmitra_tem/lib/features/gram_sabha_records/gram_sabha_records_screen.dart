// Gram Sabha Records for the village user: the village's Gram Sabha meetings from the
// VanMitra backend, split into Upcoming (today or later) and Past, in the villager
// design (landscape banner, orange-underlined tabs, leaf empty state). Tapping a
// meeting shows its agenda, attendance and quorum [Rule 4(2)].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../case_hub/case_hub_api.dart';

/// The village's meetings (newest first, as the server sends them).
final villageMeetingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, villageId) async {
  if (villageId.isEmpty) return [];
  final list = await CaseHubApi().meetings(villageId);
  return list.cast<Map<String, dynamic>>();
});

DateTime? meetingDate(Map<String, dynamic> m) => DateTime.tryParse(m['held_on'] as String? ?? '');

bool isUpcoming(Map<String, dynamic> m) {
  final d = meetingDate(m);
  if (d == null) return false;
  final now = DateTime.now();
  return !d.isBefore(DateTime(now.year, now.month, now.day));
}

/// The next meeting today or later, if any (for the dashboard card).
Map<String, dynamic>? nextMeeting(List<Map<String, dynamic>> all) {
  final upcoming = all.where(isUpcoming).toList()
    ..sort((a, b) => (a['held_on'] as String).compareTo(b['held_on'] as String));
  return upcoming.isEmpty ? null : upcoming.first;
}

class GramSabhaRecordsScreen extends ConsumerStatefulWidget {
  const GramSabhaRecordsScreen({super.key, this.bottomNavigationBar});
  final Widget? bottomNavigationBar;

  @override
  ConsumerState<GramSabhaRecordsScreen> createState() => _GramSabhaRecordsScreenState();
}

class _GramSabhaRecordsScreenState extends ConsumerState<GramSabhaRecordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _villageId => ref.read(authProvider).currentUser?.backendVillageId ?? '';

  Future<void> _refresh() => ref.refresh(villageMeetingsProvider(_villageId).future);

  void _showMeeting(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.colors.bottomSheetBg,
      builder: (_) => _MeetingSheet(meeting: m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final villageId = ref.watch(authProvider).currentUser?.backendVillageId ?? '';
    final meetings = ref.watch(villageMeetingsProvider(villageId));
    final c = context.colors;

    return PortalFrameScaffold(
      title: 'ग्रामसभा | Gram Sabha Records',
      showBreadcrumbs: false,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned(left: -20, bottom: -10, child: LeafCorner(size: 160)),
          Column(
            children: [
              const NatureBanner(height: 104),
              Container(
                decoration: BoxDecoration(
                  color: c.cardBg,
                  border: Border(bottom: BorderSide(color: c.divider)),
                ),
                child: TabBar(
                  controller: _tabs,
                  labelColor: c.isDark ? Colors.white : const Color(0xFF143526),
                  unselectedLabelColor: c.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  indicatorColor: const Color(0xFFFF7A00),
                  indicatorWeight: 3.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: 'Upcoming (येणारी बैठक)'),
                    Tab(text: 'Past (मागील नोंदी)'),
                  ],
                ),
              ),
              Expanded(
                child: meetings.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: VillagerEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load the meetings',
                      message: apiErrorText(e),
                      actionLabel: 'Try again',
                      actionIcon: Icons.refresh_rounded,
                      onAction: _refresh,
                    ),
                  ),
                  data: (all) {
                    final upcoming = all.where(isUpcoming).toList()
                      ..sort((a, b) => (a['held_on'] as String).compareTo(b['held_on'] as String));
                    final past = all.where((m) => !isUpcoming(m)).toList();
                    return TabBarView(
                      controller: _tabs,
                      children: [
                        _list(upcoming, past: false),
                        _list(past, past: true),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, {required bool past}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 50),
                VillagerEmptyState(
                  icon: past ? Icons.folder_shared_outlined : Icons.event_note_rounded,
                  title: past ? 'No past meetings yet.' : 'No meetings scheduled yet.',
                  message: past
                      ? 'Completed Gram Sabha meetings and their records will be kept here.'
                      : 'Check back for official session schedules or initiate a meeting as FRC Admin.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _MeetingCard(meeting: items[i], onTap: () => _showMeeting(items[i])),
            ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});
  final Map<String, dynamic> meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = meetingDate(meeting);
    final recorded = meeting['attendance_recorded'] == true;
    final resolutions = meeting['resolutions'] as int? ?? 0;
    final upcoming = isUpcoming(meeting);
    return VmCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: upcoming ? const Color(0xFFFFF1E0) : const Color(0xFFEAF4EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(d == null ? '–' : DateFormat('d').format(d),
                    style: TextStyle(
                        color: upcoming ? const Color(0xFFE07A00) : const Color(0xFF2E705B),
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text(d == null ? '' : DateFormat('MMM yy').format(d),
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meeting['agenda'] as String? ?? 'Gram Sabha meeting',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: c.textTertiary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(meeting['place'] as String? ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (upcoming)
                      const StatusPill(label: 'Scheduled', color: Color(0xFFE07A00), icon: Icons.event_rounded)
                    else if (recorded)
                      StatusPill(
                          label: '${meeting['present_count']} of ${meeting['registered_count']} present',
                          color: const Color(0xFF2E705B),
                          icon: Icons.groups_rounded)
                    else
                      const StatusPill(label: 'Attendance not recorded', color: Color(0xFF757575)),
                    if (resolutions > 0)
                      StatusPill(
                          label: '$resolutions resolution${resolutions == 1 ? '' : 's'}',
                          color: const Color(0xFF1E6FB8),
                          icon: Icons.gavel_rounded),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ],
      ),
    );
  }
}

class _MeetingSheet extends StatelessWidget {
  const _MeetingSheet({required this.meeting});
  final Map<String, dynamic> meeting;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = meetingDate(meeting);
    final recorded = meeting['attendance_recorded'] == true;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Text('Gram Sabha meeting',
              style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              '${d == null ? '' : DateFormat('EEEE, d MMMM yyyy').format(d)} · ${meeting['place']}',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          if (meeting['notice_on'] != null)
            Text('Notice given on ${meeting['notice_on']}',
                style: TextStyle(color: c.textTertiary, fontSize: 12)),
          const SizedBox(height: 14),
          const VmSectionTitle('Agenda'),
          Text(meeting['agenda'] as String? ?? '',
              style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.45)),
          const SizedBox(height: 16),
          const VmSectionTitle('Attendance & quorum', subtitle: 'Rule 4(2): at least half the members, one-third of them women'),
          if (!recorded)
            Text('Attendance has not been recorded for this meeting yet.',
                style: TextStyle(color: c.textSecondary, fontSize: 13))
          else
            FutureBuilder<Map<String, dynamic>>(
              future: CaseHubApi().quorum(meeting['id'] as String),
              builder: (_, snap) {
                if (snap.hasError) return Text(apiErrorText(snap.error!));
                if (!snap.hasData) return const LinearProgressIndicator();
                final q = snap.data!;
                return ChecklistCard(
                  title: q['passed'] == true ? 'Quorum met' : 'Quorum not met',
                  lines: [
                    ChecklistLine(
                      ok: q['t1'] == true,
                      text: '${q['present']} of ${q['registered']} members present (needed ${q['required_present']})',
                      rule: 'Rule 4(2)',
                    ),
                    ChecklistLine(
                      ok: q['t2'] == true,
                      text: '${q['women_present']} women present (needed ${q['required_women']})',
                      rule: 'Rule 4(2)',
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
