import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../livelihood_routes.dart';
import '../livelihood_strings.dart';

void _openAsk(BuildContext context) {
  // Already on the Ask screen: nothing to open.
  if (ModalRoute.of(context)?.settings.name == LivelihoodRoutes.ask) return;
  Navigator.of(context).pushNamed(LivelihoodRoutes.ask);
}

/// The "Ask AI" button for a header: a saffron sparkle that opens the Ask screen.
class LvAskAction extends StatelessWidget {
  const LvAskAction({super.key});

  @override
  Widget build(BuildContext context) {
    final label = LivelihoodStrings.of(context).t('lv_ask_ai');
    return IconButton(
      tooltip: label,
      onPressed: () => _openAsk(context),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.saffron,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The floating "Ask AI" button for a screen of its own.
class LvAskFab extends StatelessWidget {
  const LvAskFab({super.key});

  @override
  Widget build(BuildContext context) {
    final label = LivelihoodStrings.of(context).t('lv_ask_ai');
    return FloatingActionButton.extended(
      heroTag: 'lv_ask_fab',
      onPressed: () => _openAsk(context),
      backgroundColor: AppColors.saffron,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
