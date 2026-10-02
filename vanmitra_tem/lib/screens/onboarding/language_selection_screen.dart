import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../providers/locale_provider.dart';
import '../../services/localization_service.dart';

/// Language Selection Screen — 4 language cards in 2×2 grid
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    final localizations = AppLocalizations.of(context);
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        elevation: 0,
        title: Text(
          'वनमित्र | VanMitra',
          style: TextStyle(fontSize: 16, color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Row(
            children: [
              Expanded(child: Container(height: 3, color: AppColors.secondary)),
              Expanded(child: Container(height: 3, color: c.border)),
              Expanded(child: Container(height: 3, color: AppColors.success)),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(
                localizations.languageTitle,
                style: TextStyle(
                  fontFamily: 'NotoSansDevanagari',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizations.languageSubtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: c.textSecondary,
                ),
              ),
                const SizedBox(height: 40),

                // 2×2 grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _LanguageCard(
                        emoji: '🇬🇧',
                        name: 'English',
                        nativeName: 'English',
                        code: 'en',
                        isSelected: currentLocale.languageCode == 'en',
                        onTap: () => ref.read(localeProvider.notifier).setLocale('en'),
                      ),
                      _LanguageCard(
                        emoji: '🇮🇳',
                        name: 'Hindi',
                        nativeName: 'हिंदी',
                        code: 'hi',
                        isSelected: currentLocale.languageCode == 'hi',
                        onTap: () => ref.read(localeProvider.notifier).setLocale('hi'),
                      ),
                      _LanguageCard(
                        emoji: '🏛️',
                        name: 'Marathi',
                        nativeName: 'मराठी',
                        code: 'mr',
                        isSelected: currentLocale.languageCode == 'mr',
                        onTap: () => ref.read(localeProvider.notifier).setLocale('mr'),
                      ),
                      _LanguageCard(
                        emoji: '🌊',
                        name: 'Konkani',
                        nativeName: 'कोंकणी',
                        code: 'kn',
                        isSelected: currentLocale.languageCode == 'kn',
                        onTap: () => ref.read(localeProvider.notifier).setLocale('kn'),
                      ),
                    ],
                  ),
                ),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRouter.registration);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      elevation: 4,
                      shadowColor: AppColors.secondary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      localizations.btnContinue,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String nativeName;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.emoji,
    required this.name,
    required this.nativeName,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (c.isDark ? AppColors.forestDeep.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.05))
              : c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentSaffron : c.border,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.accentSaffron.withValues(alpha: 0.2), blurRadius: 12)]
              : (c.isDark
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              nativeName,
              style: TextStyle(
                fontFamily: 'NotoSansDevanagari',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (c.isDark ? AppColors.accentSaffron : AppColors.primary)
                    : c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSaffron.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓ Selected',
                  style: TextStyle(fontSize: 10, color: AppColors.accentSaffron, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
