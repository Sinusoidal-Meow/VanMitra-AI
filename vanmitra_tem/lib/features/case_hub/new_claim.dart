// Opening a new claim on the VanMitra backend, from anywhere in the app: a chooser with
// only the forms the signed-in role may file, then the claim's own page (Form A, B or C).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import 'case_home_screen.dart';
import 'case_hub_api.dart';

class _ClaimKind {
  const _ClaimKind(this.type, this.title, this.subtitle, this.icon, this.color);
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _formA = _ClaimKind('ifr', 'Form A · Individual claim',
    'वैयक्तिक वन हक्क दावा', Icons.person_rounded, Color(0xFFFF8A00));
const _formB = _ClaimKind('cr', 'Form B · Community rights',
    'सामूहिक हक्क दावा', Icons.groups_2_rounded, Color(0xFF2E705B));
const _formC = _ClaimKind('cfr', 'Form C · Community forest resource',
    'सामूहिक वन संसाधन दावा', Icons.forest_rounded, Color(0xFF2E705B));

/// Who may open which form (the backend enforces the same rule).
List<_ClaimKind> _allowedFor(UserRole role) => switch (role) {
      UserRole.villager => const [_formA, _formB],
      UserRole.frc => const [_formB, _formC], // the Gram Sabha
      _ => const [],
    };

/// Let the user pick a form, open the claim on the backend and show its page.
/// [onChanged] runs after the claim page is closed (e.g. to refresh a list).
Future<void> startNewBackendClaim(BuildContext context, WidgetRef ref,
    {VoidCallback? onChanged}) async {
  final user = ref.read(authProvider).currentUser;
  final kinds = _allowedFor(user?.role ?? UserRole.villager);
  final messenger = ScaffoldMessenger.of(context);
  if (user == null || kinds.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'Your role does not file claims; claims reach you for review.')));
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File a new claim · नवीन दावा दाखल करा',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final k in kinds)
                Card(
                  color: c.cardBg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: c.border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: k.color.withValues(alpha: 0.14),
                      child: Icon(k.icon, color: k.color),
                    ),
                    title: Text(k.title,
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(k.subtitle,
                        style: TextStyle(color: c.textSecondary)),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: c.textSecondary),
                    onTap: () => Navigator.pop(sheet, k),
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
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'Your account is not linked to a village on the server yet.')));
    return;
  }
  try {
    final created = await CaseHubApi().createCase(villageId, chosen.type);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaseHomeScreen(
          caseId: created['id'] as String, initialClaimType: chosen.type),
    ));
    onChanged?.call();
  } on ApiException catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('Could not open the claim: ${e.messageKey}')));
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('Could not reach the server: $e')));
  }
}
