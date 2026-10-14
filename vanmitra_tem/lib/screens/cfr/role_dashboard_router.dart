import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return dashboardWidget;
  }
}
