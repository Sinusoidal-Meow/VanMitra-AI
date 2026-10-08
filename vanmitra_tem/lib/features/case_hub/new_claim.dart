// Opening a new claim on the VanMitra backend, from anywhere in the app: a chooser with
// the community forms (Form B, Form C), then the claim's own page.
// Form A (individual claim) is no longer offered here (8 Oct 2026). A village user may
// open Form C only while the server's test setting villager_opens_form_c is on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../evidence/evidence_screen.dart';
import 'case_home_screen.dart';
import 'case_hub_api.dart';

class _ClaimKind {
  const _ClaimKind(this.type, this.title, this.subtitle, this.detail, this.icon, this.color);
  final String type;
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final Color color;
}

const _formB = _ClaimKind(
  'cr',
  'Form B · Community rights',
  'सामूहिक हक्क दावा',
  'Nistar, minor forest produce, grazing, water bodies, fishing…',
  Icons.groups_2_rounded,
  Color(0xFFFF7A00),
);
const _formC = _ClaimKind(
  'cfr',
  'Form C · Community forest resource',
  'सामूहिक वन संसाधन दावा',
  'The forest the village has traditionally protected and used, with its boundary',
  Icons.forest_rounded,
  Color(0xFF2E705B),
);

/// Which forms the role may open (the server checks the same).
List<_ClaimKind> _allowedFor(UserRole role) => switch (role) {
      UserRole.villager || UserRole.frc => const [_formB, _formC],
      _ => const [],
    };

/// Let the user pick a form, open the claim on the backend and show its page.
/// [onChanged] runs after the claim page is closed (e.g. to refresh a list).
Future<void> startNewBackendClaim(BuildContext context, WidgetRef ref, {VoidCallback? onChanged}) async {
  final user = ref.read(authProvider).currentUser;
  final kinds = _allowedFor(user?.role ?? UserRole.villager);
  final messenger = ScaffoldMessenger.of(context);
  if (user == null || kinds.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Your role does not file claims; claims reach you for review.')));
    return;
  }
  final chosen = await showModalBottomSheet<_ClaimKind>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colors.bottomSheetBg,
    builder: (sheet) {
      final c = sheet.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('File a new claim · नवीन दावा',
                  style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Choose the form for your community’s claim.',
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              for (final k in kinds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: VmCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.pop(sheet, k),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: k.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(k.icon, color: k.color, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k.title,
                                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(k.subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                              const SizedBox(height: 3),
                              Text(k.detail, style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (chosen == null || !context.mounted) return;

  final villageId = user.backendVillageId;
  if (villageId == null || villageId.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Your account is not linked to a village on the server yet.')));
    return;
  }
  try {
    final created = await CaseHubApi().createCase(villageId, chosen.type);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaseHomeScreen(caseId: created['id'] as String, initialClaimType: chosen.type),
    ));
    onChanged?.call();
  } catch (e) {
    if (context.mounted) showApiError(context, e);
  }
}

/// Dashboard "Evidence Checklist": the evidence of your open claim. With several open
/// claims, pick one; with none, the Rule 13 guide.
Future<void> openEvidenceForMyClaim(BuildContext context, WidgetRef ref) async {
  List<dynamic> mine;
  try {
    mine = await CaseHubApi().getMyCases();
  } catch (e) {
    if (context.mounted) showApiError(context, e);
    return;
  }
  if (!context.mounted) return;
  final open = mine
      .cast<Map<String, dynamic>>()
      .where((c) => !const ['rejected', 'expired', 'title_issued'].contains(c['state']))
      .toList();
  if (open.isEmpty) {
    Navigator.pushNamed(context, AppRouter.rule13Evidence);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('You have no open claim yet. File a claim, then add its evidence.'),
      action: SnackBarAction(label: 'File claim', onPressed: () => startNewBackendClaim(context, ref)),
    ));
    return;
  }
  Map<String, dynamic>? pick = open.length == 1 ? open.first : null;
  pick ??= await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colors.bottomSheetBg,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('Evidence for which claim?',
              style: TextStyle(color: sheet.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final c in open)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VmCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.pop(sheet, c),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFEAF4EE),
                      child: Text(c['form'] as String? ?? '?',
                          style: const TextStyle(color: Color(0xFF2E705B), fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formTitle(c['claim_type'] as String? ?? ''),
                              style: TextStyle(color: sheet.colors.textPrimary, fontWeight: FontWeight.w700)),
                          Text(claimStateLabel(c['state'] as String? ?? ''),
                              style: TextStyle(color: sheet.colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  final allowed = ((pick['allowed_actions'] as List<dynamic>?) ?? []).cast<String>();
  final canAdd = (pick['state'] == 'draft' && pick['is_mine'] == true) ||
      (pick['state'] == 'gs_review' && allowed.contains('approve'));
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EvidenceScreen(
      caseId: pick!['id'] as String,
      claimType: pick['claim_type'] as String? ?? 'cr',
      villageId: pick['village_id'] as String? ?? '',
      canAdd: canAdd,
    ),
  ));
}
