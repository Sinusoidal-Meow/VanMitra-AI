// Step 2 of a claim: the evidence pool [Rule 13]. Lists what has been recorded (with the
// photo, rule, place and the FRC's verification stamp), shows the documentation
// checklist, and lets the claimant add evidence while the claim is a draft.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/location/gps.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../form_b/form_b_models.dart' show kEvidenceRules;
import 'evidence_api.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({
    super.key,
    required this.caseId,
    required this.claimType,
    required this.villageId,
    required this.canAdd,
  });

  final String caseId;
  final String claimType;
  final String villageId;

  /// Claimant while drafting, or the Gram Sabha while it reviews.
  final bool canAdd;

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  final _api = EvidenceApi();
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _readiness;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.list(widget.caseId),
        _api.readiness(widget.caseId),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (results[0] as List<Map<String, dynamic>>)
            .where((e) => e['superseded'] != true)
            .toList();
        _readiness = results[1] as Map<String, dynamic>;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _addEvidence() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.bottomSheetBg,
      builder: (_) => AddEvidenceSheet(
          caseId: widget.caseId, villageId: widget.villageId),
    );
    if (saved == true) {
      if (mounted) showDone(context, 'Evidence recorded.');
      _load();
    }
  }

  void _viewPhoto(String mediaId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(child: MediaImage(mediaId: mediaId)),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'My Claims', 'Evidence'],
      floatingActionButton: widget.canAdd
          ? FloatingActionButton.extended(
              onPressed: _addEvidence,
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Add evidence',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            const NatureBanner(height: 78),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              child: _body(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return VillagerEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the evidence',
        message: apiErrorText(_error!),
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: _load,
      );
    }
    final readiness = _readiness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VmSectionTitle('Evidence · पुरावे',
            subtitle:
                'Rule 13 evidence for this claim. Photos keep their place and time.'),
        if (readiness != null)
          ChecklistCard(
            title: 'Documentation checklist',
            lines: [
              for (final i in (readiness['items'] as List<dynamic>))
                ChecklistLine(
                  ok: i['ok'] as bool,
                  text: kReadinessText[i['message_key']] ??
                      (i['message_key'] as String),
                  rule: i['rule'] as String,
                ),
            ],
            footnote:
                'A guide only: the Gram Sabha and officials decide the claim.',
          ),
        const SizedBox(height: 16),
        VmSectionTitle('Recorded evidence',
            trailing: Text('${_items.length}',
                style: const TextStyle(
                    color: Color(0xFF2E705B), fontWeight: FontWeight.w800))),
        if (_items.isEmpty)
          VillagerEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No evidence yet.',
            message: widget.canAdd
                ? 'Add photos of documents, old structures, sacred places or a signed statement of elders.'
                : 'Evidence added to this claim will appear here.',
            actionLabel: widget.canAdd ? 'Add evidence' : null,
            actionIcon: Icons.add_a_photo_rounded,
            onAction: widget.canAdd ? _addEvidence : null,
          )
        else
          for (final e in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EvidenceCard(item: e, onPhotoTap: _viewPhoto),
            ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item, required this.onPhotoTap});

  final Map<String, dynamic> item;
  final ValueChanged<String> onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rule = item['rule_ref'] as String;
    final kind = item['kind'] as String;
    final mediaId = (item['media_id'] ?? item['signed_scan_media_id']) as String?;
    final verified = item['verified'] == true;
    final created = DateTime.tryParse(item['created_at'] as String? ?? '');
    final lat = (item['gps_lat'] as num?)?.toDouble();
    final lon = (item['gps_lon'] as num?)?.toDouble();
    final verifications = (item['verifications'] as List<dynamic>? ?? []);

    return VmCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: mediaId == null ? null : () => onPhotoTap(mediaId),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 68,
                height: 68,
                child: mediaId != null
                    ? MediaImage(mediaId: mediaId, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFFEAF4EE),
                        child: Icon(_kindIcon(kind),
                            color: const Color(0xFF2E705B), size: 30),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    RuleTag('Rule $rule'),
                    StatusPill(
                        label: kEvidenceKinds[kind] ?? kind.replaceAll('_', ' '),
                        color: const Color(0xFF2E705B)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item['description'] as String? ?? '',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(kEvidenceRules[rule] ?? '',
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (created != null) ...[
                      Icon(Icons.schedule_rounded,
                          size: 13, color: c.textTertiary),
                      const SizedBox(width: 3),
                      Text(DateFormat('d MMM yyyy').format(created.toLocal()),
                          style:
                              TextStyle(color: c.textTertiary, fontSize: 11.5)),
                      const SizedBox(width: 10),
                    ],
                    if (lat != null && lon != null) ...[
                      Icon(Icons.location_on_rounded,
                          size: 13, color: c.textTertiary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                            '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textTertiary, fontSize: 11.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                verified
                    ? StatusPill(
                        label:
                            'Verified by FRC · ${(verifications.last as Map)['verified_by_name']}',
                        color: const Color(0xFF2E7D32),
                        icon: Icons.verified_rounded)
                    : const StatusPill(
                        label: 'Waiting for FRC verification',
                        color: Color(0xFFE07A00),
                        icon: Icons.hourglass_top_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(String kind) => switch (kind) {
        'document_scan' => Icons.description_rounded,
        'elder_statement' => Icons.record_voice_over_rounded,
        'text_note' => Icons.notes_rounded,
        'audio' => Icons.mic_rounded,
        'gps_point' => Icons.location_on_rounded,
        _ => Icons.photo_rounded,
      };
}

/// A protected photo from the server (sent with the login token), cached in memory.
class MediaImage extends StatelessWidget {
  const MediaImage({super.key, required this.mediaId, this.fit = BoxFit.contain});

  final String mediaId;
  final BoxFit fit;

  static final Map<String, Future<Uint8List>> _cache = {};

  @override
  Widget build(BuildContext context) {
    final future =
        _cache.putIfAbsent(mediaId, () => EvidenceApi().mediaBytes(mediaId));
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!,
              fit: fit,
              errorBuilder: (_, __, ___) => const _MediaPlaceholder(
                  icon: Icons.insert_drive_file_rounded));
        }
        if (snap.hasError) {
          _cache.remove(mediaId);
          return const _MediaPlaceholder(icon: Icons.broken_image_outlined);
        }
        return const _MediaPlaceholder(icon: Icons.image_outlined);
      },
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEAF4EE),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFF7FA98F)),
      );
}

// ── Add evidence ────────────────────────────────────────────────────────────────

/// A picked file ready to upload.
class PickedImage {
  PickedImage(this.bytes, this.name, this.mime);
  final Uint8List bytes;
  final String name;
  final String mime;
}

Future<PickedImage?> pickImageFile(ImageSource source) async {
  final x = await ImagePicker()
      .pickImage(source: source, imageQuality: 82, maxWidth: 2200);
  if (x == null) return null;
  final name = x.name;
  final lower = name.toLowerCase();
  final mime = x.mimeType ??
      (lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg');
  return PickedImage(await x.readAsBytes(), name, mime);
}

class AddEvidenceSheet extends StatefulWidget {
  const AddEvidenceSheet(
      {super.key, required this.caseId, required this.villageId});

  final String caseId;
  final String villageId;

  @override
  State<AddEvidenceSheet> createState() => _AddEvidenceSheetState();
}

class _AddEvidenceSheetState extends State<AddEvidenceSheet> {
  final _api = EvidenceApi();
  final _description = TextEditingController();
  final _transcript = TextEditingController();

  String _rule = '13(1)(c)';
  String _kind = 'photo';
  PickedImage? _file;
  PickedImage? _signedScan;
  double? _lat, _lon, _accuracy;
  DateTime? _capturedAt;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>>? _members;
  String? _elderId;

  bool get _isElder => _kind == 'elder_statement';
  bool get _needsFile => _kind == 'photo' || _kind == 'document_scan';

  @override
  void dispose() {
    _description.dispose();
    _transcript.dispose();
    super.dispose();
  }

  void _setKind(String kind) {
    setState(() {
      _kind = kind;
      if (kind == 'elder_statement') {
        _rule = '13(1)(i)';
        _loadMembers();
      }
    });
  }

  Future<void> _loadMembers() async {
    if (_members != null) return;
    try {
      final list = await _api.members(widget.villageId);
      if (mounted) setState(() => _members = list);
    } catch (e) {
      if (mounted) setState(() => _members = []);
    }
  }

  Future<void> _pickImage(ImageSource source, {bool signedScan = false}) async {
    try {
      final f = await pickImageFile(source);
      if (f == null || !mounted) return;
      setState(() {
        if (signedScan) {
          _signedScan = f;
        } else {
          _file = f;
          _capturedAt = DateTime.now();
        }
      });
      // A photo taken here gets the place it was taken.
      if (!signedScan && source == ImageSource.camera) _captureGps();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the camera or gallery.');
    }
  }

  Future<void> _captureGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final p = await currentPosition();
      if (!mounted) return;
      setState(() {
        _lat = p.latitude;
        _lon = p.longitude;
        _accuracy = p.accuracy;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is GpsUnavailable ? e.message : 'Could not get the location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Write a short description of this evidence.');
      return;
    }
    if (_needsFile && _file == null) {
      setState(() => _error = 'Take a photo or choose one from the gallery.');
      return;
    }
    if (_isElder &&
        (_elderId == null || _transcript.text.trim().isEmpty || _signedScan == null)) {
      setState(() => _error =
          'An elder statement needs the elder, what they said, and a photo of the signed statement.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? mediaId;
      String? scanId;
      if (_file != null) {
        final m = await _api.uploadMedia(
          bytes: _file!.bytes,
          filename: _file!.name,
          mime: _file!.mime,
          lat: _lat,
          lon: _lon,
          accuracyM: _accuracy,
          capturedAt: _capturedAt,
        );
        mediaId = m['id'] as String;
      }
      if (_signedScan != null) {
        final m = await _api.uploadMedia(
            bytes: _signedScan!.bytes,
            filename: _signedScan!.name,
            mime: _signedScan!.mime);
        scanId = m['id'] as String;
      }
      await _api.add(widget.caseId, {
        'rule_ref': _rule,
        'kind': _kind,
        'description': description,
        if (mediaId != null) 'media_id': mediaId,
        if (_lat != null) 'gps_lat': _lat,
        if (_lon != null) 'gps_lon': _lon,
        if (_accuracy != null) 'gps_accuracy_m': _accuracy,
        if (_isElder) 'elder_member_id': _elderId,
        if (_isElder) 'transcript': _transcript.text.trim(),
        if (scanId != null) 'signed_scan_media_id': scanId,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + inset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add evidence · पुरावा जोडा',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _label('What kind of evidence?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in kEvidenceKinds.entries)
                  ChoiceChip(
                    label: Text(k.value),
                    selected: _kind == k.key,
                    onSelected: (_) => _setKind(k.key),
                    selectedColor: const Color(0xFFFFE7CC),
                    labelStyle: TextStyle(
                        color: _kind == k.key
                            ? const Color(0xFFB45300)
                            : c.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Which Rule 13 item does it show?'),
            DropdownButtonFormField<String>(
              value: _rule,
              isExpanded: true,
              decoration: _input(),
              items: [
                for (final r in kEvidenceRules.entries)
                  DropdownMenuItem(
                    value: r.key,
                    child: Text('${r.key} · ${r.value}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _rule = v ?? _rule),
            ),
            const SizedBox(height: 14),
            _label('Description'),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: _input(
                  hint: 'e.g. Old check dam built by the village, 1978'),
            ),
            if (_needsFile) ...[
              const SizedBox(height: 14),
              _label(_kind == 'photo' ? 'Photo' : 'Photo of the document'),
              _filePicker(_file, onCamera: () => _pickImage(ImageSource.camera),
                  onGallery: () => _pickImage(ImageSource.gallery)),
              const SizedBox(height: 10),
              _gpsRow(c),
            ],
            if (_isElder) ...[
              const SizedBox(height: 14),
              _label('Elder (not a claimant)'),
              if (_members == null)
                const LinearProgressIndicator()
              else if (_members!.isEmpty)
                Text(
                    'The Gram Sabha member list is empty. The Gram Sabha adds members first.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12.5))
              else
                DropdownButtonFormField<String>(
                  value: _elderId,
                  isExpanded: true,
                  decoration: _input(hint: 'Choose the elder'),
                  items: [
                    for (final m in _members!)
                      DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text(m['name'] as String,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _elderId = v),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _transcript,
                maxLines: 3,
                decoration: _input(hint: 'What the elder said (in their words)'),
              ),
              const SizedBox(height: 10),
              _label('Photo of the signed / thumb-printed statement'),
              _filePicker(_signedScan,
                  onCamera: () =>
                      _pickImage(ImageSource.camera, signedScan: true),
                  onGallery: () =>
                      _pickImage(ImageSource.gallery, signedScan: true)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            OrangePillButton(
              label: 'Save evidence',
              icon: Icons.check_rounded,
              busy: _saving,
              expand: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gpsRow(AppThemeColors c) {
    return Row(
      children: [
        Icon(Icons.location_on_rounded,
            size: 18,
            color: _lat != null ? const Color(0xFF2E7D32) : c.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _lat != null
                ? '${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)}  (±${_accuracy?.toStringAsFixed(0) ?? '?'} m)'
                : 'No location yet',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
        ),
        TextButton.icon(
          onPressed: _locating ? null : _captureGps,
          icon: _locating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location_rounded, size: 18),
          label: const Text('Use my location'),
        ),
      ],
    );
  }

  Widget _filePicker(PickedImage? file,
      {required VoidCallback onCamera, required VoidCallback onGallery}) {
    return Row(
      children: [
        if (file != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(file.bytes,
                width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(file == null ? 'Take photo' : 'Retake'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      );

  InputDecoration _input({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: context.colors.isDark
            ? const Color(0xFF16251D)
            : const Color(0xFFF5FBF7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
      );
}
