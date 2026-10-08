class ApiEndpoints {
  // Server address from --dart-define=VANMITRA_API_BASE_URL (the same value the rest of
  // the app uses, e.g. http://127.0.0.1:8000 for a phone over USB). Accepted with or
  // without the trailing /api/v1. Default: the Android emulator's view of this PC.
  static const String _server = String.fromEnvironment(
    'VANMITRA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get baseUrl {
    final root = _server.endsWith('/') ? _server.substring(0, _server.length - 1) : _server;
    return root.endsWith('/api/v1') ? root : '$root/api/v1';
  }

  // Health
  static const String health = '/health';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/me';

  // Public
  static const String villages = '/public/villages';

  // Cases (Hub)
  static const String myCases = '/cases/mine';
  static String villageCases(String villageId) => '/villages/$villageId/cases';
  static const String reviewQueue = '/review/queue';
  static String caseDetails(String caseId) => '/cases/$caseId';

  // Forms
  static String formA(String caseId) => '/cases/$caseId/form-a';
  static String formB(String caseId) => '/cases/$caseId/form-b';
  static String formC(String caseId) => '/cases/$caseId/form-c';

  // Workflow
  static String submitCase(String caseId) => '/cases/$caseId/submit';
  static String approveCase(String caseId) => '/cases/$caseId/approve';
  static String returnCase(String caseId) => '/cases/$caseId/return';
  static String rejectCase(String caseId) => '/cases/$caseId/reject';
  static String caseHistory(String caseId) => '/cases/$caseId/history';

  // FRC
  static String frcCheck(String villageId) => '/villages/$villageId/frc/check';
  static String frc(String villageId) => '/villages/$villageId/frc';
  static String frcIntimation(String villageId) => '/villages/$villageId/frc/intimation';

  // Gram Sabha
  static String members(String villageId) => '/villages/$villageId/members';
  static String claimCalls(String villageId) => '/villages/$villageId/claim-calls';
  static String currentClaimCall(String villageId) => '/villages/$villageId/claim-calls/current';
  static String extendClaimCall(String villageId) => '/villages/$villageId/claim-calls/current/extend';
  static String meetings(String villageId) => '/villages/$villageId/meetings';
  static String attendance(String meetingId) => '/meetings/$meetingId/attendance';
  static String quorum(String meetingId) => '/meetings/$meetingId/quorum';
  static String resolutions(String meetingId) => '/meetings/$meetingId/resolutions';

  // Evidence
  static const String media = '/media';
  static String evidence(String caseId) => '/cases/$caseId/evidence';
  static String verifyEvidence(String caseId, String evidenceId) => '/cases/$caseId/evidence/$evidenceId/verify';
  static String readiness(String caseId) => '/cases/$caseId/readiness';

  // Mapping
  static String boundary(String caseId) => '/cases/$caseId/boundary';
  static String landmarks(String caseId) => '/cases/$caseId/boundary/landmarks';
  static String useZones(String caseId) => '/cases/$caseId/boundary/use-zones';
  static String walks(String caseId) => '/cases/$caseId/boundary/walks';
  static String resolveDispute(String caseId, String disputeId) => '/cases/$caseId/disputes/$disputeId/resolve';

  // Verification
  static String verification(String caseId) => '/cases/$caseId/verification';

  // Documents
  static String acknowledgement(String caseId) => '/cases/$caseId/acknowledgement';
  static String titleDraft(String caseId) => '/cases/$caseId/title-draft';
  static String documentFormA(String caseId) => '/cases/$caseId/documents/form-a/html';
  static String documentFormB(String caseId) => '/cases/$caseId/documents/form-b/html';
  static String documentFormC(String caseId) => '/cases/$caseId/documents/form-c/html';
  static String documentReceipt(String caseId) => '/cases/$caseId/documents/receipt/html';
  static String documentTitle(String caseId) => '/cases/$caseId/documents/title/html';
}
