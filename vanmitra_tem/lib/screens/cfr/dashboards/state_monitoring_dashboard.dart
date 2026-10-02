import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/claim.dart';
import '../../../models/user_role.dart';
import '../../../providers/claims_provider.dart';
import '../../../widgets/portal_frame_scaffold.dart';
import '../cfr_claim_detail_screen.dart';

/// State Level Monitoring Committee (SLMC) Read-Only Oversight Dashboard
class StateMonitoringDashboard extends ConsumerStatefulWidget {
  const StateMonitoringDashboard({super.key});

  @override
  ConsumerState<StateMonitoringDashboard> createState() =>
      _StateMonitoringDashboardState();
}

class _StateMonitoringDashboardState
    extends ConsumerState<StateMonitoringDashboard> {
  String _selectedDistrict = 'All Districts';
  String _selectedTehsil = 'All Tehsils';

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(claimsStreamProvider('ozhar_jawhar_palghar'));

    return PortalFrameScaffold(
      breadcrumbs: const ['State Level Monitoring Committee'],
      body: claimsAsync.when(
        data: (claims) => _buildDashboardContent(context, claims),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading claims: $err')),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Claim> allClaims) {
    final c = context.colors;
    var filtered = allClaims;
    if (_selectedDistrict != 'All Districts') {
      filtered = filtered.where((c) => c.district.contains(_selectedDistrict)).toList();
    }
    if (_selectedTehsil != 'All Tehsils') {
      filtered = filtered.where((c) => c.tehsil.contains(_selectedTehsil)).toList();
    }

    final total = allClaims.length;
    final inGramSabha = allClaims.where((c) => c.status == ClaimStatus.gramSabhaReview).length;
    final inFieldVerif = allClaims.where((c) => c.status.name.startsWith('fieldVerification')).length;
    final inSdlc = allClaims.where((c) => c.status.name.startsWith('sdlc')).length;
    final inDlc = allClaims.where((c) => c.status.name.startsWith('dlc')).length;
    final inAnnexureIV = allClaims.where((c) => c.status.name.startsWith('annexureIv')).length;
    final inRecords = allClaims.where((c) => c.status == ClaimStatus.recordIncorporationPending).length;
    final completed = allClaims.where((c) => c.status.isApproved).length;
    final rejected = allClaims.where((c) => c.status.isRejected).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.govtBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.query_stats_rounded, color: Colors.white, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SLMC State-Wide Oversight Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Read-only monitoring analytics across districts, sub-divisions & villages.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: c.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDistrict,
                      dropdownColor: c.cardBg,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: ['All Districts', 'Palghar', 'Gadchiroli', 'Nandurbar']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 12, color: c.textPrimary))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDistrict = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTehsil,
                      dropdownColor: c.cardBg,
                      decoration: const InputDecoration(
                        labelText: 'Tehsil',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: ['All Tehsils', 'Jawhar', 'Dahanu', 'Vikramgad']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: c.textPrimary))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTehsil = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
            children: [
              _buildStatTile('Total Claims', '$total', c.isDark ? AppColors.forestLight : AppColors.forestCanopy, c),
              _buildStatTile('Gram Sabha', '$inGramSabha', AppColors.saffron, c),
              _buildStatTile('Field Verif.', '$inFieldVerif', AppColors.govtBlue, c),
              _buildStatTile('SDLC Pending', '$inSdlc', Colors.teal, c),
              _buildStatTile('DLC Pending', '$inDlc', Colors.purple, c),
              _buildStatTile('Annexure IV', '$inAnnexureIV', Colors.pink, c),
              _buildStatTile('Record Inc.', '$inRecords', Colors.blueGrey, c),
              _buildStatTile('Completed', '$completed', AppColors.successGreen, c),
              _buildStatTile('Rejected', '$rejected', AppColors.alertRed, c),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text(
                'Claims Stream',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const Spacer(),
              Text('${filtered.length} records', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final claim = filtered[index];
              return Card(
                color: c.cardBg,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                child: ListTile(
                  title: Text(claim.id, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.textPrimary)),
                  subtitle: Text(
                    '${claim.claimantNameEn} • ${claim.villageName} • Authority: ${claim.assignedAuthority.displayNameEn}',
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: claim.status.isApproved ? AppColors.successGreen.withOpacity(0.15) : AppColors.saffron.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      claim.status.displayNameEn,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: claim.status.isApproved ? AppColors.successGreen : AppColors.saffron,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CfrClaimDetailScreen(claim: claim),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color, AppColorScheme c) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
