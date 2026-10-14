import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/host_hooks.dart';

/// The frame every livelihood screen shares: forest-green header, soft page background.
class LvScaffold extends ConsumerWidget {
  const LvScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
  });

  final String title;
  final Widget body;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          title,
          style: AppTypography.title.copyWith(color: Colors.white),
        ),
        actions: [
          ...ref.watch(hostAppBarActionsProvider),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: bottom,
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}
