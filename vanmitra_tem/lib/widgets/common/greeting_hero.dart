import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Enhanced Greeting Hero banner with:
/// - Richer multi-stop forest gradient
/// - Animated decorative background orbs
/// - Subtle glow shadow
/// - Refined avatar ring with gradient border
class GreetingHero extends StatelessWidget {
  final String userName;
  final String role;
  final String villageName;
  final VoidCallback? onProfileTap;

  const GreetingHero({
    super.key,
    required this.userName,
    required this.role,
    required this.villageName,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = userName.isEmpty ? 'VanMitra Citizen' : userName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF143526), // Deep forest
            AppColors.forestCanopy,
            AppColors.forestSage,
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        boxShadow: [
          // Primary depth shadow
          const BoxShadow(
            color: Color(0x2A0B241A),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
          // Colored ambient glow
          BoxShadow(
            color: AppColors.forestCanopy.withValues(alpha: 0.15),
            offset: const Offset(0, 8),
            blurRadius: 28,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background orbs
          Positioned(
            right: -20,
            top: -15,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -25,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.forestMist.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Main content
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with gradient ring
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.saffron, Color(0xFFFF9E3D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.saffron.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName.characters.first.toUpperCase()
                          : 'V',
                      style: AppTypography.display.copyWith(
                        color: AppColors.textOnBrand,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hello, $displayName',
                      style: AppTypography.display.copyWith(
                        color: AppColors.textOnBrand,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs + 1),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        // Role badge with subtle glassmorphism
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textOnBrand,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (villageName.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.forestMist, size: 12),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  villageName,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.forestMist,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Decorative nature icon with glow
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: AppColors.forestMist,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
