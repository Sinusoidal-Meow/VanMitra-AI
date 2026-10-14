import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Buttons the HOST wants in this feature's app bars (language and theme switches). The feature
/// does not own either setting. In the standalone shell these are the shell's toggles; at merge
/// the host leaves this empty (its own settings screen already has them) or overrides it.
final hostAppBarActionsProvider = Provider<List<Widget>>((ref) => const []);

/// True in the host's OFFLINE DEMO build. The report there is a prepared one for a sample farmer
/// (the rules run on a server, which a demo phone does not have), so every screen of this feature
/// says so in a slim strip instead of letting it pass for the person's own report.
final hostDemoModeProvider = Provider<bool>((ref) => false);

/// Everything a screen of this feature puts in its frame. The host turns it into its own frame
/// (its header, notice strip, footer and bottom navigation) so the feature looks like the rest
/// of the app without importing any host widget.
class LvFrameSpec {
  const LvFrameSpec({
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottom,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;

  /// Buttons this screen adds to its header (for example "Ask AI").
  final List<Widget> actions;

  /// A strip under the header (the Schemes tabs).
  final PreferredSizeWidget? bottom;

  /// The host's bottom navigation, when this screen is one of its tabs.
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
}

typedef LvFrameBuilder = Widget Function(BuildContext context, LvFrameSpec spec);

/// The host's frame for a screen of this feature. Null (the standalone shell) = the feature draws
/// its own plain green header.
final hostFrameBuilderProvider = Provider<LvFrameBuilder?>((ref) => null);

/// The host's green "hero" (landscape and glass card) that sits behind the top of the Livelihood
/// tab. [child] is the content that goes in front of it; the host decides what the glass card
/// says (it knows the signed-in person). Null = no hero.
typedef LvHeroBuilder = Widget Function(
  BuildContext context,
  WidgetRef ref, {
  required String badge,
  required Widget child,
});
final hostHeroBuilderProvider = Provider<LvHeroBuilder?>((ref) => null);
