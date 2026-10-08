// My Claims: the claims from the VanMitra backend in the villager design: landscape
// banner, search with a ⋮ menu, Approved / Pending / Rejected chips (tap to filter),
// claim cards, and "File New Claim". The Gram Sabha and the SDO can switch the list to
// the village's claims or their review queue from the ⋮ menu.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import 'case_home_screen.dart';
import 'case_hub_api.dart';
import 'new_claim.dart';

enum _StatusFilter { approved, pending, rejected }

enum _Source { mine, village, review }

_StatusFilter _groupOf(String state) => switch (state) {
      'title_issued' => _StatusFilter.approved,
      'rejected' || 'expired' => _StatusFilter.rejected,
      _ => _StatusFilter.pending,
    };

class CasesListScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  const CasesListScreen({super.key, this.bottomNavigationBar});

  @override
  ConsumerState<CasesListScreen> createState() => _CasesListScreenState();
}

class _CasesListScreenState extends ConsumerState<CasesListScreen> {
  final CaseHubApi _api = CaseHubApi();
  final _search = TextEditingController();

  bool _isLoading = true;
  Object? _error;
  List<dynamic> _myCases = [];
  List<dynamic> _villageCases = [];
  List<dynamic> _reviewQueue = [];

  String _query = '';
  _StatusFilter? _filter;
  bool _newestFirst = true;
  _Source _source = _Source.mine;

  bool get _isOfficial {
    final role = ref.read(authProvider).currentUser?.role;
    return role == UserRole.frc || role == UserRole.sdlc;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).currentUser;
      final villageId = user?.backendVillageId ?? '';
      final official = _isOfficial;
      final results = await Future.wait([
        _api.getMyCases(),
        if (official && villageId.isNotEmpty) _api.getVillageCases(villageId) else Future.value(<dynamic>[]),
        if (official) _api.getReviewQueue() else Future.value(<dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _myCases = results[0];
        _villageCases = results[1];
        _reviewQueue = results[2];
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String text) => setState(() => _query = text.trim().toLowerCase());

  void _toggleFilter(_StatusFilter f) => setState(() => _filter = _filter == f ? null : f);

  void _setSort(bool newestFirst) => setState(() => _newestFirst = newestFirst);

  void _setSource(_Source s) => setState(() {
        _source = s;
        _filter = null;
      });

  /// The role-aware chooser shared with the dashboard; refreshes the list afterwards.
  void _openNewClaim() => startNewBackendClaim(context, ref, onChanged: _loadData);

  void _openCase(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => CaseHomeScreen(caseId: item['id'] as String, initialClaimType: item['claim_type'] as String?),
        ))
        .then((_) => _loadData());
  }

  List<Map<String, dynamic>> get _sourceList => switch (_source) {
        _Source.mine => _myCases,
        _Source.village => _villageCases,
        _Source.review => _reviewQueue,
      }
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> _visible() {
    final list = _sourceList.where((c) {
      if (_filter != null && _groupOf(c['state'] as String? ?? '') != _filter) return false;
      if (_query.isEmpty) return true;
      final hay = [
        c['claimant_label'],
        c['form'] == null ? null : 'form ${c['form']}',
        formTitle(c['claim_type'] as String? ?? ''),
        c['village_name_en'],
        c['village_name_mr'],
        claimStateLabel(c['state'] as String? ?? ''),
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(_query);
    }).toList();
    list.sort((a, b) {
      final cmp = (a['created_at'] as String? ?? '').compareTo(b['created_at'] as String? ?? '');
      return _newestFirst ? -cmp : cmp;
    });
    return list;
  }

  Future<void> _showMenu(BuildContext anchor) async {
    final box = anchor.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay)),
      Offset.zero & overlay.size,
    );
    final choice = await showMenu<String>(
      context: context,
      position: pos,
      items: [
        const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh_rounded), title: Text('Refresh'))),
        CheckedPopupMenuItem(value: 'newest', checked: _newestFirst, child: const Text('Newest first')),
        CheckedPopupMenuItem(value: 'oldest', checked: !_newestFirst, child: const Text('Oldest first')),
        if (_isOfficial) ...[
          const PopupMenuDivider(),
          CheckedPopupMenuItem(value: 'mine', checked: _source == _Source.mine, child: const Text('My claims')),
          CheckedPopupMenuItem(value: 'village', checked: _source == _Source.village, child: const Text('Village claims')),
          CheckedPopupMenuItem(
              value: 'review',
              checked: _source == _Source.review,
              child: Text('Review queue (${_reviewQueue.length})')),
        ],
      ],
    );
    switch (choice) {
      case 'refresh':
        _loadData();
      case 'newest':
        _setSort(true);
      case 'oldest':
        _setSort(false);
      case 'mine':
        _setSource(_Source.mine);
      case 'village':
        _setSource(_Source.village);
      case 'review':
        _setSource(_Source.review);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crumb = switch (_source) {
      _Source.mine => 'My Claims',
      _Source.village => 'Village Claims',
      _Source.review => 'Review Queue',
    };
    return PortalFrameScaffold(
      breadcrumbs: ['Dashboard', crumb],
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButton: _source == _Source.mine
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OrangePillButton(label: 'File New Claim', icon: Icons.add_rounded, onPressed: _openNewClaim),
            )
          : null,
      body: Stack(
        children: [
          const Positioned(left: -24, bottom: -10, child: LeafCorner(size: 150)),
          RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: NatureBanner(height: 100)),
                SliverToBoxAdapter(child: _searchRow()),
                SliverToBoxAdapter(child: _chipsRow()),
                ..._content(),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchRow() {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: c.isDark ? const Color(0xFF16251D) : const Color(0xFFEFF5F1),
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search claims…',
                  hintStyle: TextStyle(color: c.textTertiary),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 6),
                    child: Icon(Icons.search_rounded, color: Color(0xFF143526), size: 26),
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            _onSearchChanged('');
                          },
                        ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Builder(
            builder: (anchor) => Material(
              color: c.isDark ? const Color(0xFF16251D) : const Color(0xFFEFF5F1),
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 26,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF143526)),
                tooltip: 'More',
                onPressed: () => _showMenu(anchor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipsRow() {
    final list = _sourceList;
    int count(_StatusFilter f) => list.where((c) => _groupOf(c['state'] as String? ?? '') == f).length;
    final shown = _visible().length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(_StatusFilter.approved, '${count(_StatusFilter.approved)} Approved',
                      Icons.check_circle_outline_rounded, const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                  const SizedBox(width: 8),
                  _chip(_StatusFilter.pending, '${count(_StatusFilter.pending)} Pending', Icons.schedule_rounded,
                      const Color(0xFFE09000), const Color(0xFFFFF7E0)),
                  const SizedBox(width: 8),
                  _chip(_StatusFilter.rejected, '${count(_StatusFilter.rejected)} Rejected', Icons.cancel_outlined,
                      const Color(0xFFD32F2F), const Color(0xFFFDECEC)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$shown Claim${shown == 1 ? '' : 's'}',
              style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _chip(_StatusFilter f, String label, IconData icon, Color color, Color bg) {
    final on = _filter == f;
    return InkWell(
      onTap: () => _toggleFilter(f),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.18) : bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? color : color.withValues(alpha: 0.35), width: on ? 1.6 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_isLoading && _sourceList.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator())),
        )
      ];
    }
    if (_error != null && _sourceList.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: VillagerEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your claims',
            message: apiErrorText(_error!),
            actionLabel: 'Try again',
            actionIcon: Icons.refresh_rounded,
            onAction: _loadData,
          ),
        )
      ];
    }
    final items = _visible();
    if (items.isEmpty) {
      final none = _sourceList.isEmpty;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 36),
            child: VillagerEmptyState(
              icon: Icons.folder_shared_outlined,
              title: none
                  ? (_source == _Source.review ? 'Nothing waiting for you.' : 'No claims submitted yet.')
                  : 'No claims match.',
              message: none
                  ? (_source == _Source.mine
                      ? 'Begin securing your forest community land rights under FRA 2006 today.'
                      : 'Claims will appear here when they reach you.')
                  : 'Try another search or clear the filter.',
              actionLabel: none && _source == _Source.mine ? 'File New Claim' : null,
              onAction: none && _source == _Source.mine ? _openNewClaim : null,
            ),
          ),
        )
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ClaimCard(item: items[i], onTap: () => _openCase(items[i])),
        ),
      ),
    ];
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = item['claim_type'] as String? ?? '';
    final state = item['state'] as String? ?? 'draft';
    final letter = item['form'] as String? ?? '?';
    final claimant = (item['claimant_label'] as String?)?.trim() ?? '';
    final created = DateTime.tryParse(item['created_at'] as String? ?? '');
    final returned = item['returned'] as Map<String, dynamic>?;
    final accent = type == 'cfr' ? const Color(0xFF2E705B) : const Color(0xFFFF7A00);

    return VmCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Text(letter, style: TextStyle(color: accent, fontSize: 21, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(claimant.isEmpty ? 'Draft: name not filled yet' : claimant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(formTitle(type), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(label: claimStateLabel(state), color: claimStateColor(state)),
                    if (returned != null)
                      StatusPill(
                        label: 'Sent back · ${returned['days_left']} days left',
                        color: const Color(0xFFC62828),
                        icon: Icons.timer_outlined,
                      ),
                    if (created != null)
                      Text(DateFormat('d MMM yyyy').format(created.toLocal()),
                          style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
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
