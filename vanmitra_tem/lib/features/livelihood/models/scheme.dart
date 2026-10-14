// Schemes and the idea detail (docs/to_do.md stage 3). The app only DISPLAYS what the server
// sends. A scheme row has no amount and no "you qualify": it is a link to an official page, who
// last checked it, and when. Every bundled row is labelled Sample until a real register exists.

import 'report.dart';

enum SchemeKind { government, ngo }

class Scheme {
  const Scheme({
    required this.code,
    required this.kind,
    required this.nameEn,
    required this.nameMr,
    required this.runsEn,
    required this.runsMr,
    required this.whatEn,
    required this.whatMr,
    required this.whoEn,
    required this.whoMr,
    required this.documentsEn,
    required this.documentsMr,
    required this.helpTypes,
    required this.audiences,
    required this.officialUrl,
    required this.noteEn,
    required this.noteMr,
    required this.lastCheckedOn,
    required this.isSample,
  });

  final String code;
  final SchemeKind kind;
  final String nameEn, nameMr, runsEn, runsMr, whatEn, whatMr, whoEn, whoMr;
  final List<String> documentsEn, documentsMr, helpTypes, audiences;
  final String? officialUrl;
  final String noteEn, noteMr;

  /// An ISO date, or "unknown" when no person has checked this row.
  final String lastCheckedOn;
  final bool isSample;

  bool get neverChecked => lastCheckedOn == 'unknown';

  static bool _mr(String lang) => lang == 'mr' || lang == 'hi';

  String name(String lang) => _mr(lang) && nameMr.isNotEmpty ? nameMr : nameEn;
  String runs(String lang) => _mr(lang) && runsMr.isNotEmpty ? runsMr : runsEn;
  String what(String lang) => _mr(lang) && whatMr.isNotEmpty ? whatMr : whatEn;
  String who(String lang) => _mr(lang) && whoMr.isNotEmpty ? whoMr : whoEn;
  String note(String lang) => _mr(lang) && noteMr.isNotEmpty ? noteMr : noteEn;
  List<String> documents(String lang) =>
      _mr(lang) && documentsMr.isNotEmpty ? documentsMr : documentsEn;

  static List<String> _strings(Object? raw) =>
      List<String>.from((raw as List?) ?? const []);

  factory Scheme.fromJson(Map<String, dynamic> j) => Scheme(
        code: j['code'] as String,
        kind: j['kind'] == 'ngo' ? SchemeKind.ngo : SchemeKind.government,
        nameEn: (j['name_en'] as String?) ?? '',
        nameMr: (j['name_mr'] as String?) ?? '',
        runsEn: (j['runs_en'] as String?) ?? '',
        runsMr: (j['runs_mr'] as String?) ?? '',
        whatEn: (j['what_en'] as String?) ?? '',
        whatMr: (j['what_mr'] as String?) ?? '',
        whoEn: (j['who_en'] as String?) ?? '',
        whoMr: (j['who_mr'] as String?) ?? '',
        documentsEn: _strings(j['documents_en']),
        documentsMr: _strings(j['documents_mr']),
        helpTypes: _strings(j['help_types']),
        audiences: _strings(j['audiences']),
        officialUrl: j['official_url'] as String?,
        noteEn: (j['note_en'] as String?) ?? '',
        noteMr: (j['note_mr'] as String?) ?? '',
        lastCheckedOn: (j['last_checked_on'] as String?) ?? 'unknown',
        // anything not clearly "not a sample" is treated as a sample
        isSample: j['is_sample'] != false,
      );
}

/// The filters on the Schemes screen. `null` means "all". Used as a provider key.
class SchemeFilter {
  const SchemeFilter({this.help, this.audience});

  final String? help;
  final String? audience;

  @override
  bool operator ==(Object other) =>
      other is SchemeFilter && other.help == help && other.audience == audience;

  @override
  int get hashCode => Object.hash(help, audience);
}

class SchemesResult {
  const SchemesResult({
    required this.schemes,
    required this.helpTypes,
    required this.audiences,
    required this.isSampleData,
    required this.registerEmpty,
  });

  final List<Scheme> schemes;
  final List<String> helpTypes;
  final List<String> audiences;
  final bool isSampleData;
  final bool registerEmpty;

  List<Scheme> ofKind(SchemeKind kind) =>
      schemes.where((s) => s.kind == kind).toList();

  factory SchemesResult.fromJson(Map<String, dynamic> j) => SchemesResult(
        schemes: [
          for (final s in (j['schemes'] as List? ?? const []))
            Scheme.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        helpTypes: Scheme._strings(j['help_types']),
        audiences: Scheme._strings(j['audiences']),
        isSampleData: j['is_sample_data'] != false,
        registerEmpty: j['register_empty'] == true,
      );
}

/// One thing an idea needs: alternatives, and which one he has or is near him (null = none).
class NeedInfo {
  const NeedInfo({required this.options, this.metBy});

  final List<String> options;
  final String? metBy;

  factory NeedInfo.fromJson(Map<String, dynamic> j) => NeedInfo(
        options: List<String>.from(j['options'] as List),
        metBy: j['met_by'] as String?,
      );
}

enum CheckResult { passed, flagged, notChecked }

class CheckInfo {
  const CheckInfo({
    required this.check,
    required this.result,
    required this.reason,
  });

  final String check; // law | wildlife | needs | land | community
  final CheckResult result;
  final Reason reason;

  factory CheckInfo.fromJson(Map<String, dynamic> j) => CheckInfo(
        check: j['check'] as String,
        result: switch (j['result']) {
          'passed' => CheckResult.passed,
          'flagged' => CheckResult.flagged,
          // an unknown result is never shown as a pass
          _ => CheckResult.notChecked,
        },
        reason: Reason.fromJson(Map<String, dynamic>.from(j['reason'] as Map)),
      );
}

class IdeaDetail {
  const IdeaDetail({
    required this.card,
    required this.status,
    required this.needs,
    required this.checks,
    required this.resources,
    required this.schemes,
    required this.isSampleData,
    this.rank,
    this.fit,
    this.weatherNote,
  });

  /// The idea-shaped facts (name, reason, cost, season, wildlife, flags, draft), parsed by the
  /// same code as a report's idea card.
  final IdeaCard card;
  final String status; // in_report | held_back | removed
  final int? rank;
  final FitLabel? fit;
  final List<NeedInfo> needs;
  final List<CheckInfo> checks;
  final List<ResourceItem> resources;
  final Reason? weatherNote;
  final List<Scheme> schemes;
  final bool isSampleData;

  bool get isRemoved => status == 'removed';
  bool get isHeldBack => status == 'held_back';

  String name(String lang) => card.name(lang);

  factory IdeaDetail.fromJson(Map<String, dynamic> j) => IdeaDetail(
        card: IdeaCard.fromJson({
          'rank': j['rank'] ?? 0,
          'code': j['code'],
          'name_mr': j['name_mr'],
          'name_en': j['name_en'],
          'group': j['group'] ?? 'ranked',
          'fit': j['fit'],
          'reason': j['reason'],
          'resources_used': const <String>[],
          'cost_level': j['cost_level'],
          'best_season': j['best_season'],
          'wildlife_risk': j['wildlife_risk'],
          'flags': j['flags'] ?? const [],
          'draft': j['draft'],
        }),
        status: (j['status'] as String?) ?? 'in_report',
        rank: j['rank'] as int?,
        fit: j['fit'] == null ? null : parseFitLabel(j['fit']),
        needs: [
          for (final n in (j['needs'] as List? ?? const []))
            NeedInfo.fromJson(Map<String, dynamic>.from(n as Map)),
        ],
        checks: [
          for (final c in (j['checks'] as List? ?? const []))
            CheckInfo.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        resources: [
          for (final r in (j['resources'] as List? ?? const []))
            ResourceItem.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
        weatherNote: j['weather_note'] == null
            ? null
            : Reason.fromJson(
                Map<String, dynamic>.from(j['weather_note'] as Map)),
        schemes: [
          for (final s in (j['schemes'] as List? ?? const []))
            Scheme.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        isSampleData: j['is_sample_data'] != false,
      );
}
