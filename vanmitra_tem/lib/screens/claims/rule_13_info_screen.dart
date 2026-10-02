import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../services/localization_service.dart';
import '../../widgets/portal_frame_scaffold.dart';

class Rule13InfoScreen extends StatelessWidget {
  const Rule13InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalFrameScaffold(
      breadcrumbs: [
        context.tr('tab_dashboard'),
        context.tr('rule13_title')
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.govtBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('rule13_title'),
                          style: const TextStyle(
                            fontFamily: 'NotoSansDevanagari',
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('rule13_subtitle'),
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchURL('https://tribal.nic.in/FRA/data/FRARulesBook.pdf'),
                    icon: const Icon(Icons.launch_rounded, size: 16),
                    label: Text(
                      context.tr('rule13_official_link'),
                      style: const TextStyle(fontFamily: 'NotoSansDevanagari', fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.govtBlue,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildEvidenceCard(
                    context,
                    keyName: 'government_records',
                    icon: Icons.account_balance_rounded,
                    weight: 30,
                    color: AppColors.primary,
                  ),
                  _buildEvidenceCard(
                    context,
                    keyName: 'physical_structures',
                    icon: Icons.home_work_rounded,
                    weight: 30,
                    color: AppColors.secondary,
                  ),

                  _buildEvidenceCard(
                    context,
                    keyName: 'elder_statements',
                    icon: Icons.record_voice_over_rounded,
                    weight: 20,
                    color: const Color(0xFF6B7280),
                  ),
                  _buildEvidenceCard(
                    context,
                    keyName: 'traditional_structures',
                    icon: Icons.park_rounded,
                    weight: 10,
                    color: AppColors.successGreen,
                  ),
                  _buildEvidenceCard(
                    context,
                    keyName: 'other_govt_schemes',
                    icon: Icons.assignment_ind_rounded,
                    weight: 10,
                    color: AppColors.warningAmber,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCard(BuildContext context, {
    required String keyName,
    required IconData icon,
    required int weight,
    required Color color,
  }) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
        boxShadow: c.isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('ev_cat_$keyName'),
                          style: TextStyle(
                            fontFamily: 'NotoSansDevanagari',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$weight%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('ev_desc_$keyName'),
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $url');
    }
  }
}
