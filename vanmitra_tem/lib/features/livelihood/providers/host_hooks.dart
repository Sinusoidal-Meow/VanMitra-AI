import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Buttons the HOST wants in this feature's app bars (language and theme switches). The feature
/// does not own either setting. In the standalone shell these are the shell's toggles; at merge
/// the host leaves this empty (its own settings screen already has them) or overrides it.
final hostAppBarActionsProvider = Provider<List<Widget>>((ref) => const []);
