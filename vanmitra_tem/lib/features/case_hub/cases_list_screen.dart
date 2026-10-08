import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_frame_scaffold.dart';
import 'case_hub_api.dart';
import 'dart:async';
import '../../core/routes/app_router.dart';
import '../../models/user_role.dart';

class CasesListScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  const CasesListScreen({super.key, this.bottomNavigationBar});

  @override
  ConsumerState<CasesListScreen> createState() => _CasesListScreenState();
}

class _CasesListScreenState extends ConsumerState<CasesListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CaseHubApi _api = CaseHubApi();
  
  bool _isLoading = true;
  List<dynamic> _myCases = [];
  List<dynamic> _villageCases = [];
  List<dynamic> _reviewQueue = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authProvider);
      final villageId = authState.currentUser?.villageId ?? '';
      
      final results = await Future.wait([
        _api.getMyCases(),
        if (villageId.isNotEmpty) _api.getVillageCases(villageId) else Future.value([]),
        _api.getReviewQueue(),
      ]);
      
      if (mounted) {
        setState(() {
          _myCases = results[0];
          _villageCases = results[1];
          _reviewQueue = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load cases: $e')));
      }
    }
  }

  void _openNewClaim() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open New Claim', style: TextStyle(fontFamily: 'NotoSansDevanagari')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Form A — IFR'),
              onTap: () => _createAndNavigate('ifr', ctx),
            ),
            ListTile(
              title: const Text('Form B — Community Rights'),
              onTap: () => _createAndNavigate('cr', ctx),
            ),
            ListTile(
              title: const Text('Form C — CFR'),
              onTap: () => _createAndNavigate('cfr', ctx),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _createAndNavigate(String type, BuildContext dialogCtx) async {
    Navigator.pop(dialogCtx);
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authProvider);
      final villageId = authState.currentUser?.villageId ?? '';
      final newCase = await _api.createCase(villageId, type);
      _loadData(); // refresh list
      
      if (mounted) {
        // Navigate to Case Home (stepper)
        // Using existing AppRouter if case details exist or create one
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Case created successfully!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.currentUser?.role ?? UserRole.villager;
    
    // Determine visibility based on role
    final showVillage = role == UserRole.frc || role == UserRole.sdlc || role == UserRole.admin;
    
    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'Case Hub'],
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewClaim,
        backgroundColor: AppColors.saffron,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Claim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            tabs: [
              const Tab(text: 'My Claims'),
              if (showVillage) const Tab(text: 'Village Claims') else const Tab(text: '—'),
              if (showVillage) Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Review Queue'),
                    if (_reviewQueue.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: Text('${_reviewQueue.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      )
                    ]
                  ],
                )
              ) else const Tab(text: '—'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_myCases),
                      showVillage ? _buildList(_villageCases) : const Center(child: Text('Unauthorized')),
                      showVillage ? _buildList(_reviewQueue) : const Center(child: Text('Unauthorized')),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildList(List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No cases found', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(item['claim_type']?.toString().toUpperCase() ?? 'Unknown Claim'),
            subtitle: Text('Status: ${item['status'] ?? 'DRAFT'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               // navigate to Case Details (Stepper)
            },
          ),
        );
      }
    );
  }
}
