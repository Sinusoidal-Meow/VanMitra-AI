import 'package:flutter/material.dart';

import 'screens/add_details_screen.dart';
import 'screens/livelihood_home_screen.dart';
import 'screens/policy_screen.dart';
import 'screens/report_screen.dart';
import 'screens/resources_screen.dart';

/// Route names for the feature. The host app registers them next to its own in
/// `core/routes/app_router.dart` and `app.dart` (docs/INTEGRATION.md §3): add these constants
/// and spread [livelihoodRoutes] into `MaterialApp.routes`.
class LivelihoodRoutes {
  LivelihoodRoutes._();

  static const String home = '/livelihood';
  static const String details = '/livelihood/details';
  static const String report = '/livelihood/report';
  static const String resources = '/livelihood/resources';
  static const String policy = '/livelihood/policy';
}

final Map<String, WidgetBuilder> livelihoodRoutes = {
  LivelihoodRoutes.home: (_) => const LivelihoodHomeScreen(),
  LivelihoodRoutes.details: (_) => const AddDetailsScreen(),
  LivelihoodRoutes.report: (_) => const ReportScreen(),
  LivelihoodRoutes.resources: (_) => const ResourcesScreen(),
  LivelihoodRoutes.policy: (_) => const PolicyScreen(),
};
