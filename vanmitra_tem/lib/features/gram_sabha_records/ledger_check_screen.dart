// Resolution Ledger & Chain Integrity: asks the server to re-check the village's
// tamper-evident record chain (every resolution, evidence and decision is linked to the
// one before by a hash) and shows whether it is intact or where it breaks.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../case_hub/case_hub_api.dart';

class LedgerCheckScreen extends ConsumerStatefulWidget {
  const LedgerCheckScreen({super.key});

  @override
  ConsumerState<LedgerCheckScreen> createState() => _LedgerCheckScreenState();
}

class _LedgerCheckScreenState extends ConsumerState<LedgerCheckScreen> {
  Future<Map<String, dynamic>>? _check;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    final vid = ref.read(authProvider).currentUser?.backendVillageId ?? '';
    setState(() => _check = CaseHubApi().ledgerVerify(vid));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'Profile & Settings', 'Resolution Ledger'],
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const NatureBanner(height: 78),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VmSectionTitle('Resolution Ledger & Chain Integrity',
                    subtitle:
                        'Every record of the Gram Sabha is chained to the one before it, so any change afterwards shows up here.'),
                FutureBuilder<Map<String, dynamic>>(
                  future: _check,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                          padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                    }
                    if (snap.hasError) {
                      return VillagerEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not check the ledger',
                        message: apiErrorText(snap.error!),
                        actionLabel: 'Try again',
                        actionIcon: Icons.refresh_rounded,
                        onAction: _run,
                      );
                    }
                    final r = snap.data!;
                    final ok = r['ok'] == true;
                    final color = ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
                    return VmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(ok ? Icons.verified_user_rounded : Icons.gpp_bad_rounded, color: color, size: 34),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ok ? 'Intact: ${r['length']} records, none changed' : 'Broken at record ${r['broken_at_seq']}',
                                  style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          if (!ok && r['reason'] != null) ...[
                            const SizedBox(height: 8),
                            Text('${r['broken_entity'] ?? ''}: ${r['reason']}',
                                style: TextStyle(color: c.textPrimary, fontSize: 13)),
                          ],
                          const SizedBox(height: 12),
                          Text('Latest seal', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                          SelectableText(r['head'] as String? ?? '',
                              style: TextStyle(color: c.textPrimary, fontFamily: 'monospace', fontSize: 11.5)),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _run,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Check again'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
