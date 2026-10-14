import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/host_hooks.dart';
import 'lv_ask_button.dart';

/// The frame every livelihood screen shares: forest-green header, soft page background. Inside
/// the host app the host draws the frame instead (see [hostFrameBuilderProvider]).
class LvScaffold extends ConsumerWidget {
  const LvScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.actions = const [],
    this.showAsk = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final PreferredSizeWidget? bottom;

  /// Buttons this screen adds before the host's own (language and theme switches).
  final List<Widget> actions;

  /// The "Ask AI" button in the header. Off on the Ask screen itself.
  final bool showAsk;

  /// The host's bottom navigation, when this screen is one of its tabs.
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [...actions, if (showAsk) const LvAskAction()];

    final frame = ref.watch(hostFrameBuilderProvider);
    if (frame != null) {
      return frame(
        context,
        LvFrameSpec(
          title: title,
          body: body,
          actions: all,
          bottom: bottom,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
        ),
      );
    }

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
          ...all,
          ...ref.watch(hostAppBarActionsProvider),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: bottom,
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
