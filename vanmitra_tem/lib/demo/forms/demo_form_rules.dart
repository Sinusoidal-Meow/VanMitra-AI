/// Rules of Forms A, B and C as pure functions: the printed items, the vocabularies, documentation
/// completeness and the member sheet counts. Ported from the backend (domain/form_a.py,
/// form_b.py, form_c.py and the enums in models/enums.py). No database, no HTTP.
///
/// Completeness is ADVISORY: it never blocks saving or submitting and is never a score.
library;

// ── vocabularies (models/enums.py) ───────────────────────────────────────────────

/// Rule 13 sub-clauses: every evidence item is tagged with one.
const List<String> evidenceRules = [
  '13(1)(a)',
  '13(1)(b)',
  '13(1)(c)',
  '13(1)(d)',
  '13(1)(e)',
  '13(1)(f)',
  '13(1)(g)',
  '13(1)(h)',
  '13(1)(i)',
  '13(2)(a)',
  '13(2)(b)',
  '13(2)(c)',
  '13(2)(d)',
  '13(2)(e)',
];

/// Rule 13(1) (general) as opposed to 13(2) (community forest resource).
bool isGeneralEvidence(String rule) => rule.startsWith('13(1)');

/// Where a Form C landmark lies: the four boundaries or inside the area.
const List<String> boundarySides = ['east', 'west', 'north', 'south', 'within'];

const List<String> landmarkKinds = [
  'river',
  'stream',
  'spring',
  'pond',
  'sacred_place',
  'sacred_grove',
  'burial_ground',
  'well',
  'road',
  'compartment_pillar',
  'hill',
  'other',
];

const List<String> memberCategories = ['st', 'otfd', 'other'];

// ── completeness ─────────────────────────────────────────────────────────────────

class CompletenessItem {
  const CompletenessItem(this.id, this.ok, this.formItem, this.rule, this.messageKey);

  final String id;
  final bool ok;
  final String formItem;
  final String rule;

  /// Translated by the app; shown when [ok] is false.
  final String messageKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ok': ok,
        'form_item': formItem,
        'rule': rule,
        'message_key': messageKey,
      };
}

class Completeness {
  const Completeness(this.items);

  final List<CompletenessItem> items;

  int get done => items.where((i) => i.ok).length;
  int get total => items.length;

  /// The backend's `CompletenessOut`.
  Map<String, dynamic> toJson() => {
        'done': done,
        'total': total,
        'items': [for (final i in items) i.toJson()],
      };
}

bool _filled(String? s) => s != null && s.trim().isNotEmpty;

bool _allFilled(Iterable<String?> fields) => fields.every(_filled);

// ── Form A ───────────────────────────────────────────────────────────────────────

class ClaimSpec {
  const ClaimSpec(this.code, this.formItem, this.labelEn, this.section, this.hasExtent);

  final String code;
  final String formItem;
  final String labelEn;
  final String section;

  /// Whether an area (ha) is asked for.
  final bool hasExtent;
}

/// "Nature of claim on land", in the order printed on Form A.
const List<ClaimSpec> formAClaims = [
  ClaimSpec('habitation', '1(a)', 'Extent of forest land occupied: for habitation',
      'Section 3(1)(a)', true),
  ClaimSpec('self_cultivation', '1(b)',
      'Extent of forest land occupied: for self-cultivation, if any', 'Section 3(1)(a)', true),
  ClaimSpec('disputed_land', '2', 'Disputed lands, if any', 'Section 3(1)(f)', true),
  ClaimSpec('patta_lease_grant', '3', 'Pattas / leases / grants, if any', 'Section 3(1)(g)', true),
  ClaimSpec('in_situ_rehabilitation', '4',
      'Land for in situ rehabilitation or alternative land, if any', 'Section 3(1)(m)', true),
  ClaimSpec('displaced_without_compensation', '5',
      'Land from where displaced without land compensation', 'Section 4(8)', true),
  ClaimSpec('forest_village', '6', 'Extent of land in forest villages, if any', 'Section 3(1)(h)',
      true),
  ClaimSpec('other_traditional', '7', 'Any other traditional right, if any', 'Section 3(1)(l)',
      false),
];

/// Position of each Form A claim code in the printed order.
final Map<String, int> formAClaimOrder = {
  for (var i = 0; i < formAClaims.length; i++) formAClaims[i].code: i,
};

/// Rule 11(1)(a): a claim is made "along with at least two of the evidences" in Rule 13.
const int minEvidenceItems = 2;

/// Sec 4(6): recognition of land under occupation is limited to the area under actual occupation
/// and in no case exceeds 4 hectares. Shown as a note, never as a block.
const double maxRecognisableHa = 4.0;

Completeness formACompleteness({
  required List<String?> villageFields,
  required List<String> claimantNames,
  required String? address,
  required bool? isScheduledTribe,
  required bool? isOtfd,
  required Iterable<String> claimed,
  required List<String> evidenceRulesGiven,
}) =>
    Completeness([
      CompletenessItem('FA-1', claimantNames.isNotEmpty, '1', 'Rule 11(1)(a)',
          'form_a.claimant_names_missing'),
      CompletenessItem('FA-2', _filled(address), '4', 'Rule 11(1)(a)', 'form_a.address_missing'),
      CompletenessItem('FA-3', _allFilled(villageFields), '5-8', 'Rule 11(1)(a)',
          'form_a.village_details_incomplete'),
      CompletenessItem('FA-4', isScheduledTribe != null && isOtfd != null, '9', 'Rule 11(1)(a)',
          'form_a.status_unanswered'),
      CompletenessItem('FA-5', claimed.isNotEmpty, 'Nature of claim 1-7', 'Section 3(1)',
          'form_a.no_claim_described'),
      CompletenessItem('FA-6', evidenceRulesGiven.length >= minEvidenceItems, '8',
          'Rule 11(1)(a), Rule 13(3)', 'form_a.fewer_than_two_evidences'),
    ]);

// ── Form B ───────────────────────────────────────────────────────────────────────

class RightSpec {
  const RightSpec(this.code, this.formItem, this.labelEn, this.section);

  final String code;

  /// Numbering as printed on Form B.
  final String formItem;
  final String labelEn;

  /// The provision of the Act the right arises under.
  final String section;
}

/// "Nature of community rights enjoyed", in the order printed on the form.
const List<RightSpec> formBRights = [
  RightSpec('nistar', '1', 'Community rights such as nistar, if any', 'Section 3(1)(b)'),
  RightSpec('minor_forest_produce', '2', 'Rights over minor forest produce, if any',
      'Section 3(1)(c)'),
  RightSpec('water_bodies', '3(a)',
      'Community rights: uses or entitlements (fish, water bodies), if any', 'Section 3(1)(d)'),
  RightSpec('grazing', '3(b)', 'Community rights: grazing, if any', 'Section 3(1)(d)'),
  RightSpec(
      'nomadic_pastoral_access',
      '3(c)',
      'Community rights: traditional resource access for nomadic and pastoralist, if any',
      'Section 3(1)(d)'),
  RightSpec(
      'habitat',
      '4',
      'Community tenures of habitat and habitation for PTGs and pre-agricultural '
          'communities, if any',
      'Section 3(1)(e)'),
  RightSpec('biodiversity_knowledge', '5',
      'Right to access biodiversity, intellectual property and traditional knowledge, if any',
      'Section 3(1)(k)'),
  RightSpec('other_traditional', '6', 'Other traditional right, if any', 'Section 3(1)(l)'),
];

final Map<String, int> formBRightOrder = {
  for (var i = 0; i < formBRights.length; i++) formBRights[i].code: i,
};

/// Documentation completeness for a Form B draft: which items are still empty. Advisory. It says
/// nothing about eligibility and blocks nothing.
Completeness formBCompleteness({
  required List<String?> villageFields,
  required List<String> claimantNames,
  required bool? isFdstCommunity,
  required bool? isOtfdCommunity,
  required Iterable<String> claimedRights,
  required List<String> evidenceRulesGiven,
}) =>
    Completeness([
      CompletenessItem(
          'B-1', claimantNames.isNotEmpty, '1', 'Rule 11(1)(a)', 'form_b.claimant_names_missing'),
      CompletenessItem('B-2', isFdstCommunity != null && isOtfdCommunity != null, '1(a), 1(b)',
          'Rule 11(1)(a)', 'form_b.community_status_unanswered'),
      CompletenessItem('B-3', _allFilled(villageFields), '2-5', 'Rule 11(1)(a)',
          'form_b.village_details_incomplete'),
      CompletenessItem('B-4', claimedRights.isNotEmpty, 'Nature of community rights, 1-6',
          'Section 3(1)', 'form_b.no_right_described'),
      CompletenessItem('B-5', evidenceRulesGiven.length >= minEvidenceItems, '7',
          'Rule 11(1)(a), Rule 13(3)', 'form_b.fewer_than_two_evidences'),
    ]);

// ── Form C ───────────────────────────────────────────────────────────────────────

/// Item 5a, as printed on Form C. The FRC may edit it or replace it with the Marathi text.
const String defaultResolutionStatement =
    'We, the undersigned residents of this Gram Sabha hereby resolve that the area detailed '
    'below and in the attached map comprises our Community Forest Resource over which we are '
    'claiming recognition of our forest rights under Section 3(1)(i).';

const List<String> fourSides = ['east', 'west', 'north', 'south'];

/// Rule 11(1)(a): at least two evidences; a CFR claim also needs Rule 13(2) evidence (Spec 4.3).
const int minGeneralEvidence = 2;
const int minCfrEvidence = 1;

class MemberSheetCounts {
  const MemberSheetCounts({required this.total, required this.st, required this.otfd});

  final int total;
  final int st;
  final int otfd;
}

MemberSheetCounts memberSheetCounts(Iterable<String> categories) {
  final cats = categories.toList();
  return MemberSheetCounts(
    total: cats.length,
    st: cats.where((c) => c == 'st').length,
    otfd: cats.where((c) => c == 'otfd').length,
  );
}

/// Documentation completeness for a Form C draft. Advisory: it says nothing about eligibility and
/// blocks nothing. Item 6 (khasra) is optional by design and not checked.
Completeness formCCompleteness({
  required List<String?> villageFields,
  required MemberSheetCounts members,
  required String? resolutionStatement,
  required String? areaDescription,
  required Iterable<String> landmarkSides,
  required int borderingVillageCount,
  required List<String> evidenceRulesGiven,
}) {
  final sides = landmarkSides.toSet();
  final general = evidenceRulesGiven.where(isGeneralEvidence).length;
  final cfr = evidenceRulesGiven.where((r) => !isGeneralEvidence(r)).length;
  return Completeness([
    CompletenessItem('FC-1', _allFilled(villageFields), '1-4', 'Rule 11(1)',
        'form_c.village_details_incomplete'),
    CompletenessItem('FC-2', members.total > 0 && (members.st + members.otfd) > 0, '5',
        'Form C item 5', 'form_c.member_sheet_missing_st_otfd'),
    CompletenessItem('FC-3', _filled(resolutionStatement), '5a', 'Section 3(1)(i)',
        'form_c.resolution_statement_missing'),
    CompletenessItem(
        'FC-4', _filled(areaDescription), '5b', 'Rule 12(1)(g)', 'form_c.area_not_described'),
    CompletenessItem('FC-5', fourSides.every(sides.contains), '5b', 'Rule 12(1)(g)',
        'form_c.boundary_landmarks_missing'),
    CompletenessItem(
        'FC-6', borderingVillageCount > 0, '7', 'Rule 11(1)(b)', 'form_c.no_bordering_village'),
    CompletenessItem('FC-7', general >= minGeneralEvidence, '8', 'Rule 11(1)(a), Rule 13(3)',
        'form_c.fewer_than_two_general_evidences'),
    CompletenessItem(
        'FC-8', cfr >= minCfrEvidence, '8', 'Rule 13(2)', 'form_c.no_cfr_evidence'),
  ]);
}
