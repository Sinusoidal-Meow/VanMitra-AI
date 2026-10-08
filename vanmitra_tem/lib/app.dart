import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'models/claim.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'services/localization_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/language_selection_screen.dart';
import 'screens/onboarding/registration_screen.dart';
import 'screens/home/villager_home_screen.dart';
import 'screens/home/admin_home_screen.dart';
import 'screens/home/boundary_map_screen.dart';
import 'screens/gram_sabha/gram_sabha_dashboard.dart';
import 'screens/gram_sabha/create_meeting_screen.dart';
import 'screens/gram_sabha/meeting_detail_screen.dart';
import 'screens/gram_sabha/gram_sabha_log_screen.dart';
import 'screens/gram_sabha/resolution_ledger_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'core/routes/app_router.dart';
import 'features/form_b/form_b_home_screen.dart';
import 'screens/claims/claim_type_selection_screen.dart';
import 'screens/claims/claim_form_screen.dart';
import 'screens/claims/evidence_checklist_screen.dart';
import 'screens/claims/draft_preview_screen.dart';
import 'features/case_hub/cases_list_screen.dart';
import 'screens/claims/rejection_analysis_screen.dart';
import 'screens/claims/appeal_draft_screen.dart';
import 'screens/claims/rule_13_info_screen.dart';

// CFR Workflow Screens
import 'screens/cfr/role_dashboard_router.dart';
import 'screens/cfr/cfr_claim_create_screen.dart';
import 'screens/cfr/cfr_claim_detail_screen.dart';

// Module C — Gram Sabha advanced screens
import 'screens/gram_sabha/member_enrolment_screen.dart';
import 'screens/gram_sabha/resolution_recording_screen.dart';
import 'screens/gram_sabha/mom_viewer_screen.dart';

// Module B — Satellite alert screens
import 'screens/home/alert_detail_screen.dart';
import 'screens/home/alert_history_screen.dart';

/// Root MaterialApp for VanMitra-AI
class VanMitraApp extends ConsumerWidget {
  const VanMitraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'VanMitra-AI | वनमित्र',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: LocaleNotifier.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Use English fallback for locales without Material translations
      localeResolutionCallback: (locale, supportedLocales) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale?.languageCode) {
            return supported;
          }
        }
        return const Locale('en');
      },
      initialRoute: AppRouter.splash,
      builder: (context, child) {
        // Enforce mobile-sized viewport on Web/Desktop
        return Container(
          color: Colors.black, // Dark background outside the mobile frame
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: ClipRect(
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
      routes: {
        AppRouter.splash: (_) => const SplashScreen(),
        AppRouter.languageSelection: (_) => const LanguageSelectionScreen(),
        AppRouter.registration: (_) => const RegistrationScreen(),
        AppRouter.villagerHome: (_) => const VillagerHomeScreen(),
        AppRouter.adminHome: (_) => const AdminHomeScreen(),
        AppRouter.gramSabhaDashboard: (_) => const GramSabhaDashboard(),
        AppRouter.createMeeting: (_) => const CreateMeetingScreen(),
        AppRouter.meetingDetail: (_) => const MeetingDetailScreen(),
        AppRouter.resolutionLedger: (_) => const ResolutionLedgerScreen(),

        // CFR Role-Based Workflow Routes
        AppRouter.cfrRoleDashboard: (_) => const RoleDashboardRouter(),
        AppRouter.cfrClaimCreate: (_) => const CfrClaimCreateScreen(),
        AppRouter.formB: (_) => const FormBHomeScreen(),

        // Module A — Claims
        AppRouter.claimType: (_) => const ClaimTypeSelectionScreen(),
        AppRouter.claimForm: (_) => const ClaimFormScreen(),
        AppRouter.evidenceChecklist: (_) => const EvidenceChecklistScreen(),
        AppRouter.claimDraft: (_) => const DraftPreviewScreen(),
        AppRouter.myClaims: (_) => const CasesListScreen(),
        AppRouter.rejectionCheck: (_) => const RejectionAnalysisScreen(),
        AppRouter.appealDraft: (_) => const AppealDraftScreen(),
        AppRouter.rule13Evidence: (_) => const Rule13InfoScreen(),

        // Module B — CFR Boundary Map
        AppRouter.boundaryMap: (_) => const BoundaryMapScreen(),

        // Module C — Gram Sabha advanced screens
        AppRouter.memberEnrolment: (_) => const MemberEnrolmentScreen(),

        // Profile & Settings
        AppRouter.profile: (_) => const ProfileScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRouter.cfrClaimDetail) {
          final claim = settings.arguments as Claim;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => CfrClaimDetailScreen(claim: claim),
          );
        }
        if (settings.name == AppRouter.attendanceManagement) {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => GramSabhaLogScreen(
              meetingId: args['meetingId'] as String? ?? '',
              villageId: args['villageId'] as String? ?? '',
              registeredCount: args['registeredCount'] as int? ?? 100,
            ),
          );
        }
        if (settings.name == AppRouter.resolutionRecording) {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ResolutionRecordingScreen(
              meetingId: args['meetingId'] as String? ?? '',
              villageId: args['villageId'] as String? ?? '',
              language: args['language'] as String? ?? 'mr',
            ),
          );
        }
        if (settings.name == AppRouter.momViewer) {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => MomViewerScreen(
              villageId: args['villageId'] as String? ?? '',
            ),
          );
        }
        if (settings.name == AppRouter.alertDetail) {
          final alert = settings.arguments as dynamic;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AlertDetailScreen(alert: alert),
          );
        }
        if (settings.name == AppRouter.alertHistory) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const AlertHistoryScreen(),
          );
        }
        return null;
      },
    );
  }
}
