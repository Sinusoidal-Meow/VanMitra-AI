import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../demo/demo_mode.dart';
import '../features/livelihood/providers/host_hooks.dart';
import '../providers/auth_provider.dart';
import '../providers/village_provider.dart';
import '../screens/home/villager_dashboard/villager_hero_section.dart';
import 'portal_frame_scaffold.dart';

/// Module 4 (VanRozgar) draws its screens with the host's own frame, so they look like the rest
/// of VanMitra: the same header, notice strip, footer and bottom navigation, and the same green
/// hero behind the top of the Livelihood tab. The feature itself imports none of this; it asks
/// for it through the two hooks in `features/livelihood/providers/host_hooks.dart`.
///
/// Passed to the app's ProviderContainer in `main.dart`.
final List<Override> livelihoodHostOverrides = [
  hostFrameBuilderProvider.overrideWithValue(_frame),
  hostHeroBuilderProvider.overrideWithValue(_hero),
  // the offline demo build says so on every Module 4 screen (the report is a prepared one)
  hostDemoModeProvider.overrideWithValue(DemoMode.enabled),
];

Widget _frame(BuildContext context, LvFrameSpec spec) {
  Widget body = spec.body;
  final strip = spec.bottom;
  if (strip != null) {
    // the Schemes tabs sit on a green strip under the header
    body = Column(
      children: [
        Material(color: AppColors.forestCanopy, child: strip),
        Expanded(child: body),
      ],
    );
  }
  return PortalFrameScaffold(
    title: spec.title,
    showBreadcrumbs: false,
    actions: spec.actions,
    bottomNavigationBar: spec.bottomNavigationBar,
    floatingActionButton: spec.floatingActionButton,
    body: body,
  );
}

Widget _hero(
  BuildContext context,
  WidgetRef ref, {
  required String badge,
  required Widget child,
}) {
  final auth = ref.watch(authProvider);
  final village = ref.watch(villageProvider);
  final user = auth.currentUser;
  return VillagerHeroSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: HeroGeometry.cardTop),
              if (user != null)
                VillagerGlassProfileCard(
                  userName: user.name,
                  roleLabel: badge,
                  place: village?.nameMarathi ?? user.villageId,
                )
              else
                const SizedBox(height: HeroGeometry.cardHeight),
              const SizedBox(
                height: HeroGeometry.contentTop -
                    HeroGeometry.cardTop -
                    HeroGeometry.cardHeight,
              ),
            ],
          ),
        ),
        child,
      ],
    ),
  );
}
