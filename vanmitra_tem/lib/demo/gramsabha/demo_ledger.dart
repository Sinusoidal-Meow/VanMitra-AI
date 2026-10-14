import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/demo_core.dart';

/// What [DemoLedger.verify] found (the backend's `ChainReport`).
class ChainReport {
  const ChainReport({
    required this.ok,
    required this.length,
    required this.head,
    this.brokenAtSeq,
    this.brokenEntity,
    this.reason,
  });

  final bool ok;
  final int length;
  final String head;
  final int? brokenAtSeq;
  final String? brokenEntity;
  final String? reason;

  /// The backend's `LedgerReportOut`.
  Map<String, dynamic> toJson() => {
        'ok': ok,
        'length': length,
        'head': head,
        'broken_at_seq': brokenAtSeq,
        'broken_entity': brokenEntity,
        'reason': reason,
      };
}

/// Tamper-evident hash chain, one chain per Gram Sabha (backend services/ledger.py):
///
///     record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )
///
/// [append] links a record already added to the database into its Gram Sabha's chain; [verify]
/// recomputes every link from the stored records and reports the first break. The chain head is
/// kept on `gram_sabha.chain_head_hash`. Entries live in table `ledger_entry`.
class DemoLedger {
  DemoLedger._();

  static const String genesis = '0000000000000000000000000000000000000000000000000000000000000000';

  static const String table = 'ledger_entry';

  /// The record as stored: every field, keys sorted, no whitespace, so it is stable across runs.
  /// [asciiOnly] writes non-ASCII letters as `\uXXXX` (Python's default `json.dumps`).
  static String canonicalPayload(Object? value, {bool asciiOnly = false}) =>
      _canon(value, asciiOnly);

  static String _canon(Object? v, bool ascii) {
    if (v == null) return 'null';
    if (v is bool || v is int) return '$v';
    if (v is num) return v.toString();
    if (v is String) {
      final s = jsonEncode(v);
      if (!ascii) return s;
      final out = StringBuffer();
      for (final unit in s.codeUnits) {
        if (unit < 128) {
          out.writeCharCode(unit);
        } else {
          out.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
        }
      }
      return out.toString();
    }
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '${_canon(k, ascii)}:${_canon(v[k], ascii)}').join(',')}}';
    }
    if (v is Iterable) return '[${v.map((e) => _canon(e, ascii)).join(',')}]';
    return _canon('$v', ascii);
  }

  static String sha256Hex(String text) => sha256.convert(utf8.encode(text)).toString();

  static String linkHash(String payload, String prevHash) => sha256Hex(payload + prevHash);

  /// The collection a row belongs to, judged by its fields, for callers (such as the workflow)
  /// that hand over only the row. Anything unrecognised is a workflow event.
  static String entityOf(Map<String, dynamic> row) {
    if (row.containsKey('quorum_proof')) return 'resolution';
    if (row.containsKey('attempt_no')) return 'verification_proceeding';
    if (row.containsKey('evidence_id') && row.containsKey('verified_by_user_id')) {
      return 'evidence_verification';
    }
    if (row.containsKey('rule_ref') && row.containsKey('kind')) return 'evidence';
    return 'workflow_event';
  }

  /// Add [row] (already in the table [entity]) to the chain of [gramSabhaId].
  static Map<String, dynamic> append(
    DemoDb db,
    String gramSabhaId,
    String entity,
    Map<String, dynamic> row,
  ) {
    final gs = db.byId('gram_sabha', gramSabhaId);
    if (gs == null) throw StateError('gram sabha $gramSabhaId not found');
    final prev = (gs['chain_head_hash'] as String?) ?? genesis;
    final seq = ((gs['chain_length'] as int?) ?? 0) + 1;
    final entry = db.add(table, {
      'gram_sabha_id': gramSabhaId,
      'seq': seq,
      'entity': entity,
      'entity_id': row['id'],
      'prev_hash': prev,
      'record_hash': linkHash(canonicalPayload(row), prev),
    });
    gs['chain_head_hash'] = entry['record_hash'];
    gs['chain_length'] = seq;
    db.touch(gs);
    return entry;
  }

  /// Recompute every link and report the first altered or missing record.
  static ChainReport verify(DemoDb db, String gramSabhaId) {
    final entries = db.where(table, (e) => e['gram_sabha_id'] == gramSabhaId)
      ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    var prev = genesis;
    for (final e in entries) {
      final entity = e['entity'] as String;
      final seq = e['seq'] as int;
      final row = db.byId(entity, e['entity_id'] as String?);
      if (row == null) {
        return ChainReport(
          ok: false,
          length: entries.length,
          head: prev,
          brokenAtSeq: seq,
          brokenEntity: entity,
          reason: 'record missing',
        );
      }
      if (e['prev_hash'] != prev) {
        return ChainReport(
          ok: false,
          length: entries.length,
          head: prev,
          brokenAtSeq: seq,
          brokenEntity: entity,
          reason: 'chain link broken',
        );
      }
      if (linkHash(canonicalPayload(row), prev) != e['record_hash']) {
        return ChainReport(
          ok: false,
          length: entries.length,
          head: prev,
          brokenAtSeq: seq,
          brokenEntity: entity,
          reason: 'record altered',
        );
      }
      prev = e['record_hash'] as String;
    }
    final gs = db.byId('gram_sabha', gramSabhaId);
    final head = gs?['chain_head_hash'];
    if (entries.isNotEmpty && head != prev) {
      return ChainReport(
        ok: false,
        length: entries.length,
        head: prev,
        reason: 'chain head mismatch',
      );
    }
    return ChainReport(ok: true, length: entries.length, head: prev);
  }
}
