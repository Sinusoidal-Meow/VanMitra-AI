import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'demo_documents.dart';
import 'evidence_validation.dart';
import 'readiness.dart';

/// Evidence, readiness, uploaded media, documents and the written acknowledgement (backend
/// api/v1/evidence.py, media.py, documents.py, services/acknowledgement.py, readiness.py).
///
///  - Evidence is append-only (a correction is a new row that supersedes the old one and says why).
///    The claimant adds evidence while drafting; the Gram Sabha adds and verifies it while it
///    reviews. A verifier who is a claimant in the case is refused (Rule 3(3)).
///  - An elder's statement must come from a Gram Sabha member who is not a claimant (Rule 13(1)(i)).
///    GPS and satellite items never count alone (BR-06).
///  - Uploaded files are kept (base64) in `media_blob`, keyed by their SHA-256, so a photo taken in
///    the demo can be shown again. They are served only to the uploader or to someone who may see
///    a case that uses them.
///
/// Tables (the backend's collection names): `evidence`, `evidence_verification`, `media`,
/// `media_blob`, `recusal`, and the `counters` section. Also reads `case_claimant`, `claim_call`,
/// `correspondence`, `verification_proceeding`, `resolution`, `cfr_boundary`, `dispute` written by
/// other slices.
class DemoEvidence {
  DemoEvidence._();

  /// The largest upload (the backend's `max_upload_mb`).
  static const int maxUploadMb = 20;

  static const Set<String> allowedMime = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/wav',
    'audio/x-wav',
    'audio/ogg',
    'audio/webm',
  };

  // ── acknowledgement (services/acknowledgement.py) ───────────────────────────

  /// Give the case its serial (once) and link it to the current call for claims [Rule 11(3)].
  /// Serial: `<village code>/<year>/<nnnn>`, a counter per Gram Sabha and year.
  static void issueAcknowledgement(
    DemoDb db,
    Map<String, dynamic> theCase,
    Map<String, dynamic> village,
  ) {
    final today = db.todayIst();
    if (theCase['ack_serial'] == null) {
      final lgd = '${village['lgd_code'] ?? ''}';
      final name = '${village['name_en']}';
      final code = (lgd.isNotEmpty ? lgd : name.substring(0, name.length < 3 ? name.length : 3))
          .toUpperCase()
          .replaceAll(' ', '');
      final year = today.substring(0, 4);
      final key = 'ack/${theCase['gram_sabha_id']}/$year';
      final counters = db.section('counters');
      final number = ((counters[key] as num?) ?? 0).toInt() + 1;
      counters[key] = number;
      theCase['ack_serial'] = '$code/$year/${number.toString().padLeft(4, '0')}';
      theCase['acknowledged_on'] = today;
    }
    if (theCase['claim_call_id'] == null) {
      final call = db.findOne(
        'claim_call',
        (c) => c['gram_sabha_id'] == theCase['gram_sabha_id'] && c['is_current'] == true,
      );
      if (call != null) {
        theCase['claim_call_id'] = call['id'];
        final closes = (call['extended_to'] ?? call['window_ends_on']) as String?;
        theCase['filed_within_window'] = closes != null &&
            '${call['called_on']}'.compareTo(today) <= 0 &&
            today.compareTo(closes) <= 0;
      }
    }
  }

  // ── evidence ───────────────────────────────────────────────────────────────

  static Never _notAnObject(Object? body) {
    throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
      'errors': [
        {
          'type': 'model_attributes_type',
          'loc': ['body'],
          'msg': 'Input should be a valid dictionary or object to extract fields from',
          'input': body,
        },
      ],
    });
  }

  /// The parsed, trimmed fields of an EvidenceCreate (or EvidenceCorrect) body; 422 when invalid.
  static Map<String, dynamic> _parse(DemoRequest req, {bool correction = false}) {
    final b = req.body;
    if (b is! Map) _notAnObject(b);
    final c = Checker('body');
    final m = Map<String, dynamic>.from(b);
    final out = <String, dynamic>{
      'rule_ref': c.choice(m, 'rule_ref', evidenceRules, required: true),
      'kind': c.choice(m, 'kind', evidenceKinds, required: true),
      'description': c.text(m, 'description', min: 1, max: 4000, required: true),
      'media_id': c.uuid(m, 'media_id'),
      'source_office': c.text(m, 'source_office', min: 1, max: 200),
      'ref_no': c.text(m, 'ref_no', max: 100),
      'doc_date': c.date(m, 'doc_date'),
      'gps_lat': c.number(m, 'gps_lat', ge: -90, le: 90),
      'gps_lon': c.number(m, 'gps_lon', ge: -180, le: 180),
      'gps_accuracy_m': c.number(m, 'gps_accuracy_m', ge: 0),
      'elder_member_id': c.uuid(m, 'elder_member_id'),
      'transcript': c.text(m, 'transcript', min: 1, max: 4000),
      'signed_scan_media_id': c.uuid(m, 'signed_scan_media_id'),
      if (correction)
        'correction_reason': c.text(m, 'correction_reason', min: 5, max: 4000, required: true),
    };
    c.done();
    return out;
  }

  /// Claimant while drafting; Gram Sabha while it reviews the claim.
  static void _ensureCanAdd(CaseCtx ctx) {
    final state = ctx.state;
    if (state == CaseStates.draft && ctx.isCreator) return;
    if (state == CaseStates.gsReview && ctx.roles.contains(Roles.gramSabha)) return;
    throw DemoError(403, 'CANNOT_ADD_EVIDENCE_NOW', 'evidence.cannot_add_now',
        details: {'state': state});
  }

  static void _checkMedia(DemoDb db, String userId, String? mediaId) {
    if (mediaId == null) return;
    final media = db.byId('media', mediaId);
    if (media == null || media['uploaded_by_user_id'] != userId) {
      throw DemoError(422, 'MEDIA_NOT_YOURS', 'evidence.media_not_yours',
          details: {'media_id': mediaId});
    }
  }

  static void _validate(DemoDb db, CaseCtx ctx, Map<String, dynamic> v, String userId) {
    _checkMedia(db, userId, v['media_id'] as String?);
    _checkMedia(db, userId, v['signed_scan_media_id'] as String?);
    final kind = v['kind'];
    if (kind == 'elder_statement') {
      if (v['rule_ref'] != '13(1)(i)' || v['elder_member_id'] == null) {
        throw DemoError(422, 'ELDER_STATEMENT_FIELDS', 'evidence.elder_statement_fields');
      }
      final elder = db.byId('gs_member', v['elder_member_id'] as String?);
      if (elder == null || elder['gram_sabha_id'] != ctx.theCase['gram_sabha_id']) {
        throw DemoError(422, 'ELDER_NOT_IN_ROSTER', 'evidence.elder_not_in_roster');
      }
      if (CaseFacts.claimantMemberIds(db, '${ctx.theCase['id']}').contains(v['elder_member_id'])) {
        throw DemoError(409, 'ELDER_IS_CLAIMANT', 'evidence.elder_is_claimant',
            rule: 'Rule 13(1)(i)', details: {'elder_member_id': v['elder_member_id']});
      }
    }
    if (kind == 'gps_point' && (v['gps_lat'] == null || v['gps_lon'] == null)) {
      throw DemoError(422, 'GPS_POINT_NEEDS_COORDINATES', 'evidence.gps_needs_coordinates');
    }
  }

  static Map<String, dynamic> _newRow(CaseCtx ctx, Map<String, dynamic> v, String userId) => {
        'case_id': ctx.theCase['id'],
        'rule_ref': v['rule_ref'],
        'kind': v['kind'],
        'description': v['description'],
        'media_id': v['media_id'],
        'source_office': v['source_office'],
        'ref_no': v['ref_no'],
        'doc_date': v['doc_date'],
        'gps_lat': v['gps_lat'],
        'gps_lon': v['gps_lon'],
        'gps_accuracy_m': v['gps_accuracy_m'],
        'is_substitutable': isSubstitutableKind(v['kind'] as String),
        'elder_member_id': v['elder_member_id'],
        'transcript': v['transcript'],
        'signed_scan_media_id': v['signed_scan_media_id'],
        'supersedes_id': null,
        'correction_reason': null,
        'added_by_user_id': userId,
      };

  /// The backend's `EvidenceOut` for each row.
  static List<Map<String, dynamic>> _out(
    DemoDb db,
    List<Map<String, dynamic>> rows,
    Set<String> superseded,
  ) {
    final ids = {for (final r in rows) r['id']};
    final verifications = <String, List<Map<String, dynamic>>>{};
    for (final v in db.table('evidence_verification')) {
      if (ids.contains(v['evidence_id'])) {
        verifications.putIfAbsent('${v['evidence_id']}', () => []).add(v);
      }
    }
    return [
      for (final r in rows)
        {
          'id': r['id'],
          'rule_ref': r['rule_ref'],
          'kind': r['kind'],
          'description': r['description'],
          'media_id': r['media_id'],
          'source_office': r['source_office'],
          'ref_no': r['ref_no'],
          'doc_date': r['doc_date'],
          'gps_lat': r['gps_lat'],
          'gps_lon': r['gps_lon'],
          'gps_accuracy_m': r['gps_accuracy_m'],
          'is_substitutable': r['is_substitutable'],
          'elder_member_id': r['elder_member_id'],
          'transcript': r['transcript'],
          'signed_scan_media_id': r['signed_scan_media_id'],
          'supersedes_id': r['supersedes_id'],
          'superseded': superseded.contains(r['id']),
          'correction_reason': r['correction_reason'],
          'verified': (verifications['${r['id']}'] ?? const []).isNotEmpty,
          'verifications': [
            for (final v in verifications['${r['id']}'] ?? const <Map<String, dynamic>>[])
              {
                'verified_by_name': v['verified_by_name'],
                'remarks': v['remarks'],
                'at': v['created_at'],
              },
          ],
          'created_at': r['created_at'],
        },
    ];
  }

  static Map<String, dynamic> _evidenceInCase(DemoDb db, String caseId, String evidenceId) {
    final row = db.byId('evidence', evidenceId);
    if (row == null || row['case_id'] != caseId) {
      throw DemoError(404, 'EVIDENCE_NOT_FOUND', 'evidence.not_found');
    }
    return row;
  }

  static bool _isSuperseded(DemoDb db, String evidenceId) =>
      db.findOne('evidence', (e) => e['supersedes_id'] == evidenceId) != null;

  // ── media ──────────────────────────────────────────────────────────────────

  static Map<String, dynamic> mediaOut(Map<String, dynamic> m) => {
        'id': m['id'],
        'sha256': m['sha256'],
        'mime': m['mime'],
        'size_bytes': m['size_bytes'],
        'original_name': m['original_name'],
        'captured_at': m['captured_at'],
        'gps_lat': m['gps_lat'],
        'gps_lon': m['gps_lon'],
        'gps_accuracy_m': m['gps_accuracy_m'],
        'created_at': m['created_at'],
      };

  /// The media record if the caller uploaded it or may see a case that uses it; otherwise 404.
  static Map<String, dynamic> _accessible(DemoRequest req, String mediaId) {
    final db = req.db;
    final p = req.who;
    final media = db.byId('media', mediaId);
    if (media == null) throw DemoError(404, 'MEDIA_NOT_FOUND', 'media.not_found');
    if (media['uploaded_by_user_id'] == p.userId) return media;
    final caseIds = {
      for (final e in db.table('evidence'))
        if (e['media_id'] == mediaId || e['signed_scan_media_id'] == mediaId) '${e['case_id']}',
    };
    for (final caseId in caseIds) {
      try {
        DemoCases.load(db, p, caseId);
        return media;
      } on DemoError {
        continue;
      }
    }
    throw DemoError(404, 'MEDIA_NOT_FOUND', 'media.not_found');
  }

  /// The multipart upload as the demo receives it: `{file_base64, filename, mime, fields}`
  /// (see `ApiClient.upload`).
  static Map<String, dynamic> _upload(DemoRequest req) {
    final db = req.db;
    final p = req.who;
    final body = req.json;
    final fields = body['fields'] is Map
        ? Map<String, dynamic>.from(body['fields'] as Map)
        : <String, dynamic>{};
    final form = Checker('body');
    final encoded = body['file_base64'];
    if (encoded is! String) form.add('file', 'missing', 'Field required', null);
    final capturedAt = form.moment(fields, 'captured_at');
    final lat = form.number(fields, 'gps_lat', ge: -90, le: 90);
    final lon = form.number(fields, 'gps_lon', ge: -180, le: 180);
    final acc = form.number(fields, 'gps_accuracy_m', ge: 0);
    form.done();

    final mime = '${body['mime'] ?? ''}'.toLowerCase();
    if (!allowedMime.contains(mime)) {
      throw DemoError(415, 'UNSUPPORTED_MEDIA_TYPE', 'media.unsupported_type',
          details: {'mime': mime});
    }
    final Uint8List data;
    try {
      data = base64Decode(encoded as String);
    } on FormatException {
      throw DemoError(422, 'EMPTY_FILE', 'media.empty');
    }
    const limit = maxUploadMb * 1024 * 1024;
    if (data.length > limit) {
      throw DemoError(413, 'FILE_TOO_LARGE', 'media.too_large',
          details: {'max_mb': limit ~/ 1048576});
    }
    if (data.isEmpty) throw DemoError(422, 'EMPTY_FILE', 'media.empty');

    final digest = sha256.convert(data).toString();
    if (db.byId('media_blob', digest) == null) {
      db.add('media_blob', {'id': digest, 'data': base64Encode(data)});
    }
    final name = body['filename'];
    final row = db.add('media', {
      'sha256': digest,
      'mime': mime,
      'size_bytes': data.length,
      'original_name': name is String && name.isNotEmpty ? name : null,
      'storage_key': '${digest.substring(0, 2)}/$digest',
      'uploaded_by_user_id': p.userId,
      'captured_at': capturedAt,
      'gps_lat': lat,
      'gps_lon': lon,
      'gps_accuracy_m': acc,
    });
    return mediaOut(row);
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    // the written acknowledgement when a claim is first filed, Rule 11(3)
    DemoHooks.onSubmit = issueAcknowledgement;

    r.post('/cases/{case_id}/evidence', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      final v = _parse(req);
      final db = req.db;
      final ctx = DemoCases.load(db, p, caseId);
      _ensureCanAdd(ctx);
      _validate(db, ctx, v, p.userId);
      final row = db.add('evidence', _newRow(ctx, v, p.userId));
      DemoHooks.ledgerAppend(db, '${ctx.theCase['gram_sabha_id']}', row);
      return _out(db, [row], const {}).first;
    });

    r.get('/cases/{case_id}/evidence', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      var includeSuperseded = false;
      final raw = req.q('include_superseded');
      if (raw != null) {
        const yes = {'true', '1', 'yes', 'on', 't', 'y'};
        const no = {'false', '0', 'no', 'off', 'f', 'n'};
        final t = raw.toLowerCase();
        if (yes.contains(t)) {
          includeSuperseded = true;
        } else if (!no.contains(t)) {
          throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
            'errors': [
              {
                'type': 'bool_parsing',
                'loc': ['query', 'include_superseded'],
                'msg': 'Input should be a valid boolean, unable to interpret input',
                'input': raw,
              },
            ],
          });
        }
      }
      final db = req.db;
      DemoCases.load(db, p, caseId);
      var rows = db.where('evidence', (e) => e['case_id'] == caseId);
      final superseded = {
        for (final e in rows)
          if (e['supersedes_id'] != null) e['supersedes_id'] as String,
      };
      if (!includeSuperseded) rows = [for (final e in rows) if (!superseded.contains(e['id'])) e];
      return _out(db, rows, superseded);
    });

    // a correction never edits the record: it adds a row that supersedes it (BR-15)
    r.post('/cases/{case_id}/evidence/{evidence_id}/correct', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      final evidenceId = pathUuid(req, 'evidence_id');
      final v = _parse(req, correction: true);
      final db = req.db;
      final ctx = DemoCases.load(db, p, caseId);
      _ensureCanAdd(ctx);
      final old = _evidenceInCase(db, caseId, evidenceId);
      if (_isSuperseded(db, '${old['id']}')) {
        throw DemoError(409, 'ALREADY_SUPERSEDED', 'evidence.already_superseded');
      }
      _validate(db, ctx, v, p.userId);
      final row = _newRow(ctx, v, p.userId)
        ..['supersedes_id'] = old['id']
        ..['correction_reason'] = v['correction_reason'];
      db.add('evidence', row);
      DemoHooks.ledgerAppend(db, '${ctx.theCase['gram_sabha_id']}', row);
      return _out(db, [row], const {}).first;
    });

    // the Gram Sabha / FRC attests an item while reviewing the claim
    r.post('/cases/{case_id}/evidence/{evidence_id}/verify', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      final evidenceId = pathUuid(req, 'evidence_id');
      String? remarks;
      if (req.body != null) {
        if (req.body is! Map) _notAnObject(req.body);
        final c = Checker('body');
        remarks = c.text(Map<String, dynamic>.from(req.body as Map), 'remarks', min: 1, max: 4000);
        c.done();
      }
      final db = req.db;
      final ctx = DemoCases.load(db, p, caseId);
      if (!ctx.roles.contains(Roles.gramSabha)) {
        throw DemoError(403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level');
      }
      if (ctx.state != CaseStates.gsReview) {
        throw DemoError(409, 'NOT_UNDER_GS_REVIEW', 'evidence.not_under_gs_review');
      }
      final row = _evidenceInCase(db, caseId, evidenceId);
      if (_isSuperseded(db, '${row['id']}')) {
        throw DemoError(409, 'ALREADY_SUPERSEDED', 'evidence.already_superseded');
      }
      // BR-02: a claimant may not verify the case they are party to [Rule 3(3)]
      final memberId = db.byId('app_user', p.userId)?['gs_member_id'] as String?;
      if (memberId != null && CaseFacts.claimantMemberIds(db, caseId).contains(memberId)) {
        final recorded = db.findOne(
          'recusal',
          (x) => x['case_id'] == caseId && x['gs_member_id'] == memberId,
        );
        if (recorded == null) {
          db.add('recusal', {
            'case_id': caseId,
            'gs_member_id': memberId,
            'reason': 'Claimant in this case; may not verify it [Rule 3(3)]',
            'recorded_at': db.nowIso(),
          });
        }
        throw DemoError(409, 'VERIFIER_IS_CLAIMANT', 'evidence.verifier_is_claimant',
            rule: 'Rule 3(3)');
      }
      final already = db.findOne(
        'evidence_verification',
        (x) => x['evidence_id'] == row['id'] && x['verified_by_user_id'] == p.userId,
      );
      if (already != null) throw DemoError(409, 'ALREADY_VERIFIED', 'evidence.already_verified');
      final v = db.add('evidence_verification', {
        'evidence_id': row['id'],
        'verified_by_user_id': p.userId,
        'verified_by_name': p.name,
        'remarks': remarks,
      });
      DemoHooks.ledgerAppend(db, '${ctx.theCase['gram_sabha_id']}', v);
      return _out(db, [row], const {}).first;
    });

    // data for the G4 acknowledgement receipt [Rule 11(3)]; issued when the claim is filed
    r.get('/cases/{case_id}/acknowledgement', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      final db = req.db;
      final ctx = DemoCases.load(db, p, caseId);
      final c = ctx.theCase;
      final village = ctx.village;
      if (c['ack_serial'] == null || c['acknowledged_on'] == null) {
        throw DemoError(409, 'NOT_YET_FILED', 'acknowledgement.not_yet_filed');
      }
      return {
        'case_id': c['id'],
        'serial': c['ack_serial'],
        'acknowledged_on': c['acknowledged_on'],
        'form': ClaimTypes.letter[c['claim_type']],
        'claim_type': c['claim_type'],
        'claimant_label': DemoCases.claimantLabel(c, village),
        'village': DemoDocuments.villageLabel(village),
        'gram_panchayat': village['gram_panchayat'],
        'filed_within_window': c['filed_within_window'],
        'documents_received': DemoDocuments.documentsReceived(db, c),
      };
    });

    // documentation completeness R1-R10 (advisory): what is still missing, with its rule
    r.get('/cases/{case_id}/readiness', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      final db = req.db;
      final ctx = DemoCases.load(db, p, caseId);
      final c = CaseFacts.compute(db, ctx);
      return {
        'done': c.done,
        'total': c.total,
        'items': [for (final i in c.items) i.toJson()],
        'case_id': ctx.theCase['id'],
        'claim_type': ctx.theCase['claim_type'],
      };
    });

    // ── media ──
    // the multipart upload: ApiClient.upload sends method 'UPLOAD'
    r.add('UPLOAD', '/media', _upload);

    r.get('/media/{media_id}', (req) {
      req.who;
      return mediaOut(_accessible(req, pathUuid(req, 'media_id')));
    });

    // the stored bytes: ApiClient.getBytes sends method 'BYTES'; a plain GET answers the same
    Uint8List file(DemoRequest req) {
      req.who;
      final media = _accessible(req, pathUuid(req, 'media_id'));
      final blob = req.db.byId('media_blob', media['sha256'] as String?);
      if (blob == null) throw DemoError(404, 'MEDIA_NOT_FOUND', 'media.not_found');
      return base64Decode(blob['data'] as String);
    }

    r.add('BYTES', '/media/{media_id}/file', file);
    r.get('/media/{media_id}/file', file);

    DemoDocuments.register(r);
  }
}
