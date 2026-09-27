import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import 'dashboards/generic_role_dashboard.dart';
import 'dashboards/state_monitoring_dashboard.dart';

/// Central Dashboard Router directing the user to their role-specific CFR dashboard
class RoleDashboardRouter extends ConsumerWidget {
  const RoleDashboardRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to access CFR Dashboard.')),
      );
    }

    Widget dashboardWidget;

    if (user.role == UserRole.slmc) {
      dashboardWidget = const StateMonitoringDashboard();
    } else {
      dashboardWidget = GenericRoleDashboard(role: user.role);
    }

    return Column(
      children: [
        // Quick Demo Role Switcher Header
        _buildDemoRoleBar(context, ref, user.role),
        Expanded(child: dashboardWidget),
      ],
    );
  }

  Widget _buildDemoRoleBar(
      BuildContext context, WidgetRef ref, UserRole currentRole) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.person_pin_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Text(
            'Demo Active: ${currentRole.displayNameEn}',
            style: const TextStyle(
                color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showRoleSwitchDialog(context, ref, currentRole),
            icon: const Icon(Icons.swap_horiz_rounded,
                size: 14, color: Colors.white),
            label: const Text(
              'Switch Role',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleSwitchDialog(
      BuildContext context, WidgetRef ref, UserRole currentRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch Demo Role (12 CFR Roles)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
              final isSelected = role == currentRole;
              return ListTile(
                dense: true,
                title: Text(role.displayNameEn,
                    style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(role.displayNameMr,
                    style: const TextStyle(fontSize: 10)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.forestCanopy)
                    : null,
                onTap: () {
                  ref.read(authProvider.notifier).loginAsDemoRole(role);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
