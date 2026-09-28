
/// Named route constants for VanMitra-AI
class AppRouter {
  AppRouter._();

  // Onboarding
  static const String splash = '/';
  static const String languageSelection = '/language';
  static const String registration = '/registration';

  // Home
  static const String villagerHome = '/villager-home';
  static const String adminHome = '/admin-home';
  static const String gramSabhaDashboard = '/gram-sabha-dashboard';

  // CFR Role-Based Workflows
  static const String cfrRoleDashboard = '/cfr/dashboard';
  static const String cfrClaimCreate = '/cfr/create';
  static const String cfrClaimDetail = '/cfr/detail';

  // Form B (community rights) on the new VanMitra backend
  static const String formB = '/form-b';

  // Village Info
  static const String villageDashboard = '/village-dashboard';
  static const String approvedClaims = '/approved-claims';
  static const String fraRightsInfo = '/fra-rights';

  // Gram Sabha
  static const String gramSabhaHome = '/gram-sabha';
  static const String upcomingMeetings = '/gram-sabha/upcoming';
  static const String createMeeting = '/gram-sabha/create';
  static const String meetingDetail = '/gram-sabha/meeting';
  static const String selfCheckin = '/gram-sabha/checkin';
  static const String faceEnrollment = '/gram-sabha/face-enroll';
  static const String attendanceDashboard = '/gram-sabha/attendance';
  static const String quorumDashboard = '/gram-sabha/quorum';
  static const String inclusionReport = '/gram-sabha/inclusion';
  static const String createResolution = '/gram-sabha/resolution/create';
  static const String resolutionDetail = '/gram-sabha/resolution';
  static const String resolutionLedger = '/gram-sabha/ledger';
  static const String chainVerification = '/gram-sabha/verify-chain';
  static const String meetingSummary = '/gram-sabha/summary';

  // Module C routes
  static const String memberEnrolment     = '/gram-sabha/member-enrolment';
  static const String gramSabhaLog        = '/gram-sabha/log';
  static const String resolutionRecording = '/gram-sabha/resolution-recording';
  static const String momViewer           = '/gram-sabha/mom-viewer';
  static const String oversightDashboard  = '/gram-sabha/oversight';
  static const String attendanceManagement = gramSabhaLog;

  // Module A — Claims
  static const String claimType = '/claims/type';
  static const String claimForm = '/claims/form';
  static const String evidenceChecklist = '/claims/evidence';
  static const String claimDraft = '/claims/draft';
  static const String rejectionCheck = '/claims/rejection';
  static const String appealDraft = '/claims/appeal';
  static const String myClaims = '/claims/my';

  // Module B — Map
  static const String boundaryMap = '/map/boundary';
  static const String alertDetail = '/map/alert';
  static const String alertHistory = '/map/alerts';

  // Legal Reference
  static const String fraReference = '/legal/fra';
  static const String rule4Quorum = '/legal/rule4';
  static const String rule13Evidence = '/legal/rule13';
  static const String pesaRights = '/legal/pesa';

  // Profile
  static const String profile = '/profile';
  static const String settings = '/settings';
}
