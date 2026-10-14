// The report the backend sends (docs/BACKEND_PLAN.md §6). The app only DISPLAYS it: the gates,
// labels and ranking all run on the server. There is deliberately no numeric score anywhere in
// these models (rule L5): the user sees labels, never numbers like 0.72.

/// A statement as a key plus facts. The text is rendered in the user's language by
/// LivelihoodStrings, so a cached report still works offline and in any language.
class Reason {
  const Reason(this.key, [this.params = const {}]);

  final String key;
  final Map<String, dynamic> params;

  factory Reason.fromJson(Map<String, dynamic> j) => Reason(
        j['key'] as String,
        Map<String, dynamic>.from((j['params'] as Map?) ?? const {}),
      );
}

enum UsefulLabel { useful, partlyUseful, notUseful }

enum FitLabel { good, fair, weak }

enum Wildlife { low, medium, needsPermission }

T _enum<T>(List<T> values, Object? raw, T fallback, String Function(T) wire) {
  for (final v in values) {
    if (wire(v) == raw) return v;
  }
  return fallback;
}

UsefulLabel _useful(Object? raw) =>
    _enum(UsefulLabel.values, raw, UsefulLabel.partlyUseful, (v) {
      switch (v) {
        case UsefulLabel.useful:
          return 'useful';
        case UsefulLabel.partlyUseful:
          return 'partly_useful';
        case UsefulLabel.notUseful:
          return 'not_useful';
      }
    });

FitLabel _fit(Object? raw) =>
    _enum(FitLabel.values, raw, FitLabel.fair, (v) => v.name);

/// A fit label from its wire name; an unknown one is read as the middle label, never the best.
FitLabel parseFitLabel(Object? raw) => _fit(raw);

Wildlife _wildlife(Object? raw) =>
    _enum(Wildlife.values, raw, Wildlife.medium, (v) {
      switch (v) {
        case Wildlife.low:
          return 'low';
        case Wildlife.medium:
          return 'medium';
        case Wildlife.needsPermission:
          return 'needs_permission';
      }
    });

/// Source, date and check status: nothing is shown without it (rule L1).
class TrustLabel {
  const TrustLabel({
    required this.source,
    required this.sourceDate,
    required this.checkStatus,
    this.confidence,
  });

  final String source;
  final String sourceDate;
  final String checkStatus; // to_verify | confirmed
  final String? confidence;

  bool get isConfirmed => checkStatus == 'confirmed';

  factory TrustLabel.fromJson(Map<String, dynamic> j) => TrustLabel(
        source: j['source'] as String,
        sourceDate: j['source_date'] as String,
        checkStatus: j['check_status'] as String,
        confidence: j['confidence'] as String?,
      );
}

class ResourceItem {
  const ResourceItem({
    required this.id,
    required this.kind,
    required this.nameMr,
    required this.nameEn,
    required this.distanceM,
    required this.tag,
    required this.label,
    required this.reason,
    required this.checkedOnGround,
    required this.unknownChecks,
    required this.useOnlyThroughGramSabha,
    required this.trust,
  });

  final String id;
  final String kind;
  final String nameMr;
  final String nameEn;
  final int distanceM;
  final String tag; // inside_cfr | inside_village | near
  final UsefulLabel label;
  final Reason reason;
  final bool checkedOnGround;
  final List<String> unknownChecks;
  final bool useOnlyThroughGramSabha;
  final TrustLabel trust;

  String name(String lang) =>
      (lang == 'mr' || lang == 'hi') && nameMr.isNotEmpty ? nameMr : nameEn;

  factory ResourceItem.fromJson(Map<String, dynamic> j) => ResourceItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        nameMr: (j['name_mr'] as String?) ?? '',
        nameEn: (j['name_en'] as String?) ?? '',
        distanceM: (j['distance_m'] as num).toInt(),
        tag: j['tag'] as String,
        label: _useful(j['label']),
        reason: Reason.fromJson(j['reason'] as Map<String, dynamic>),
        checkedOnGround: j['checked_on_ground'] as bool,
        unknownChecks: List<String>.from(j['unknown_checks'] as List),
        useOnlyThroughGramSabha: j['use_only_through_gram_sabha'] as bool,
        trust: TrustLabel.fromJson(j['trust'] as Map<String, dynamic>),
      );
}

class Counts {
  const Counts({
    required this.useful,
    required this.partlyUseful,
    required this.notUseful,
    required this.total,
  });

  final int useful;
  final int partlyUseful;
  final int notUseful;
  final int total;

  factory Counts.fromJson(Map<String, dynamic> j) => Counts(
        useful: j['useful'] as int,
        partlyUseful: j['partly_useful'] as int,
        notUseful: j['not_useful'] as int,
        total: j['total'] as int,
      );
}

class ToldByYou {
  const ToldByYou({required this.kind, required this.code, this.count});

  final String kind; // animal | asset
  final String code;
  final int? count;

  factory ToldByYou.fromJson(Map<String, dynamic> j) => ToldByYou(
        kind: j['kind'] as String,
        code: j['code'] as String,
        count: j['count'] as int?,
      );
}

class Analysis {
  const Analysis({
    required this.headline,
    required this.strengths,
    required this.constraints,
    required this.ownResources,
    required this.nextSteps,
    required this.notes,
  });

  final Reason headline;
  final List<Reason> strengths;
  final List<Reason> constraints;
  final List<Reason> ownResources;
  final List<Reason> nextSteps;
  final List<String> notes;

  static List<Reason> _reasons(Object? raw) => [
        for (final r in (raw as List? ?? const []))
          Reason.fromJson(r as Map<String, dynamic>),
      ];

  factory Analysis.fromJson(Map<String, dynamic> j) => Analysis(
        headline: Reason.fromJson(j['headline'] as Map<String, dynamic>),
        strengths: _reasons(j['strengths']),
        constraints: _reasons(j['constraints']),
        ownResources: _reasons(j['own_resources']),
        nextSteps: _reasons(j['next_steps']),
        notes: List<String>.from((j['notes'] as List?) ?? const []),
      );
}

class IdeaCard {
  const IdeaCard({
    required this.rank,
    required this.code,
    required this.nameMr,
    required this.nameEn,
    required this.group,
    required this.fit,
    required this.reason,
    required this.resourcesUsed,
    required this.costLevel,
    required this.bestSeason,
    required this.wildlifeRisk,
    required this.flags,
    required this.draft,
    this.schemesCount = 0,
  });

  final int rank;
  final String code;
  final String nameMr;
  final String nameEn;
  final String group; // ranked | build_on_your_work | other_options
  final FitLabel fit;
  final Reason reason;
  final List<String> resourcesUsed;
  final String costLevel;
  final String bestSeason;
  final Wildlife wildlifeRisk;
  final List<Reason> flags;
  final bool draft;

  /// How many register rows (Sample until a real register exists) may relate to this idea.
  final int schemesCount;

  String name(String lang) =>
      (lang == 'mr' || lang == 'hi') && nameMr.isNotEmpty ? nameMr : nameEn;

  factory IdeaCard.fromJson(Map<String, dynamic> j) => IdeaCard(
        rank: j['rank'] as int,
        code: j['code'] as String,
        nameMr: (j['name_mr'] as String?) ?? '',
        nameEn: (j['name_en'] as String?) ?? '',
        group: j['group'] as String,
        fit: _fit(j['fit']),
        reason: Reason.fromJson(j['reason'] as Map<String, dynamic>),
        resourcesUsed: List<String>.from(j['resources_used'] as List),
        costLevel: j['cost_level'] as String,
        bestSeason: j['best_season'] as String,
        wildlifeRisk: _wildlife(j['wildlife_risk']),
        flags: Analysis._reasons(j['flags']),
        draft: (j['draft'] as bool?) ?? true,
        schemesCount: (j['schemes_count'] as num?)?.toInt() ?? 0,
      );
}

class RemovedIdea {
  const RemovedIdea({
    required this.code,
    required this.nameMr,
    required this.nameEn,
    required this.gate,
    required this.reason,
  });

  final String code;
  final String nameMr;
  final String nameEn;
  final String? gate; // null = held back, not removed
  final Reason reason;

  String name(String lang) =>
      (lang == 'mr' || lang == 'hi') && nameMr.isNotEmpty ? nameMr : nameEn;

  factory RemovedIdea.fromJson(Map<String, dynamic> j) => RemovedIdea(
        code: j['code'] as String,
        nameMr: (j['name_mr'] as String?) ?? '',
        nameEn: (j['name_en'] as String?) ?? '',
        gate: j['gate'] as String?,
        reason: Reason.fromJson(j['reason'] as Map<String, dynamic>),
      );
}

class WeatherMonth {
  const WeatherMonth({
    required this.month,
    required this.rainMm,
    required this.tmaxC,
  });

  final int month;
  final double rainMm;
  final double tmaxC;

  factory WeatherMonth.fromJson(Map<String, dynamic> j) => WeatherMonth(
        month: j['month'] as int,
        rainMm: (j['rain_mm'] as num).toDouble(),
        tmaxC: (j['tmax_c'] as num).toDouble(),
      );
}

class Weather {
  const Weather({required this.isSample, required this.months});

  final bool isSample;
  final List<WeatherMonth> months;

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
        isSample: j['is_sample'] as bool,
        months: [
          for (final m in j['months'] as List)
            WeatherMonth.fromJson(m as Map<String, dynamic>),
        ],
      );
}

class ReportHeader {
  const ReportHeader({
    required this.name,
    required this.villageMr,
    required this.villageEn,
    required this.level,
    required this.radiusM,
    required this.centreSource,
    required this.trust,
  });

  final String name;
  final String villageMr;
  final String villageEn;
  final String level; // plot | village
  final int radiusM;
  final String centreSource; // gps | manual | village_centre
  final TrustLabel trust;

  String village(String lang) =>
      (lang == 'mr' || lang == 'hi') && villageMr.isNotEmpty
          ? villageMr
          : villageEn;

  factory ReportHeader.fromJson(Map<String, dynamic> j) {
    final village = j['village'] as Map<String, dynamic>;
    return ReportHeader(
      name: j['name'] as String,
      villageMr: (village['name_mr'] as String?) ?? '',
      villageEn: (village['name_en'] as String?) ?? '',
      level: j['report_level'] as String,
      radiusM: j['radius_m'] as int,
      centreSource: (j['centre'] as Map<String, dynamic>)['source'] as String,
      trust: TrustLabel.fromJson(j['trust'] as Map<String, dynamic>),
    );
  }
}

class Report {
  const Report({
    required this.id,
    required this.generatedAt,
    required this.dataVersion,
    required this.isSampleData,
    required this.newerVersionAvailable,
    required this.header,
    required this.resources,
    required this.counts,
    required this.toldByYou,
    required this.analysis,
    required this.ideas,
    required this.removed,
    required this.weather,
    required this.disastersIsSample,
    required this.footerKey,
  });

  final String id;
  final DateTime generatedAt;
  final String dataVersion;
  final bool isSampleData;
  final bool newerVersionAvailable;
  final ReportHeader header;
  final List<ResourceItem> resources;
  final Counts counts;
  final List<ToldByYou> toldByYou;
  final Analysis analysis;
  final List<IdeaCard> ideas;
  final List<RemovedIdea> removed;
  final Weather? weather;
  final bool disastersIsSample;
  final String footerKey;

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        generatedAt: DateTime.parse(j['generated_at'] as String),
        dataVersion: j['data_version'] as String,
        isSampleData: j['is_sample_data'] as bool,
        newerVersionAvailable: (j['newer_version_available'] as bool?) ?? false,
        header: ReportHeader.fromJson(j['header'] as Map<String, dynamic>),
        resources: [
          for (final r in j['resources'] as List)
            ResourceItem.fromJson(r as Map<String, dynamic>),
        ],
        counts: Counts.fromJson(j['counts'] as Map<String, dynamic>),
        toldByYou: [
          for (final t in j['told_by_you'] as List)
            ToldByYou.fromJson(t as Map<String, dynamic>),
        ],
        analysis: Analysis.fromJson(j['analysis'] as Map<String, dynamic>),
        ideas: [
          for (final i in j['ideas'] as List)
            IdeaCard.fromJson(i as Map<String, dynamic>),
        ],
        removed: [
          for (final r in j['removed'] as List)
            RemovedIdea.fromJson(r as Map<String, dynamic>),
        ],
        weather: j['weather'] == null
            ? null
            : Weather.fromJson(j['weather'] as Map<String, dynamic>),
        disastersIsSample: ((j['disasters']
                as Map<String, dynamic>?)?['is_sample'] as bool?) ??
            true,
        footerKey: (j['footer_key'] as String?) ?? 'footer.suggestion_only',
      );
}
