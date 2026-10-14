import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/api/api_client.dart';
import 'livelihood_api.dart';
import '../models/report.dart';
import 'livelihood_cache.dart';

/// A report, and where it came from. `fromCache` is true when the server could not be reached
/// and this is the last report saved on the phone, so the screen can say so (honest gaps, L6).
class ReportResult {
  const ReportResult(this.report, {this.fromCache = false, this.savedAt});

  final Report report;
  final bool fromCache;
  final DateTime? savedAt;
}

/// The one door the screens use to get a report (PDF §16), so no screen knows where data comes
/// from. Implementations: the bundled sample, and the server with an on-phone fallback.
abstract class LivelihoodRepository {
  /// A report for his current details. [radiusM] defaults to the server's 5 km.
  Future<ReportResult> report({int? radiusM});
}

/// Reads the bundled report, which the backend built from SAMPLE (synthetic) data. Used when no
/// server or login is configured (the demo), and as the safe fallback in development.
class SeedLivelihoodRepository implements LivelihoodRepository {
  const SeedLivelihoodRepository({
    this.assetPath = 'assets/livelihood/sample_report.json',
  });

  final String assetPath;

  @override
  Future<ReportResult> report({int? radiusM}) async {
    final raw = await rootBundle.loadString(assetPath);
    return ReportResult(
      Report.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    );
  }
}

/// Builds his report on the server (POST /livelihood/report). If there is no network, or the
/// server itself fails, it falls back to the last report saved on the phone. A 4xx (not signed
/// in, no village, a bad request) is NOT hidden by the cache: he needs to see it.
class RemoteLivelihoodRepository implements LivelihoodRepository {
  RemoteLivelihoodRepository(this._api, this._cache);

  final LivelihoodApi _api;
  final LivelihoodCache _cache;

  static const _path = '/livelihood/report';

  @override
  Future<ReportResult> report({int? radiusM}) async {
    try {
      final raw = await _api.post(
        _path,
        body: {if (radiusM != null) 'radius_m': radiusM},
      ) as Map<String, dynamic>;
      final result = ReportResult(Report.fromJson(raw));
      await _cache.writeJson(LivelihoodCache.reportKey, {
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'report': raw,
      });
      return result;
    } on NetworkException {
      return _cachedOrRethrow();
    } on ApiException catch (e) {
      if (e.statusCode >= 500) return _cachedOrRethrow(e);
      rethrow;
    }
  }

  Future<ReportResult> _cachedOrRethrow([Object? original]) async {
    final saved = await _cache.readJson(LivelihoodCache.reportKey);
    if (saved != null && saved['report'] is Map<String, dynamic>) {
      try {
        return ReportResult(
          Report.fromJson(saved['report'] as Map<String, dynamic>),
          fromCache: true,
          savedAt: DateTime.tryParse((saved['saved_at'] as String?) ?? ''),
        );
      } catch (_) {
        await _cache.remove(
          LivelihoodCache.reportKey,
        ); // an unreadable old report is dropped
      }
    }
    throw original ?? const NetworkException();
  }
}
