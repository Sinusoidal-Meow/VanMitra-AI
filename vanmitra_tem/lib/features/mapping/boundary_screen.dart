// Step 3 of a Form C claim: the community forest resource boundary [Rule 12(1)(g)].
// Draw it by tapping the map or by walking it with GPS; it is split into the four sides
// (चतु:सीमा), each of which needs a landmark. Use zones and the boundary walk with
// elders are recorded here too, and overlaps with neighbours are shown [Rule 12(3)].

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location/gps.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../evidence/evidence_api.dart';
import '../evidence/evidence_screen.dart' show MediaImage, PickedImage, pickImageFile;
import '../form_c/form_c_models.dart' show kLandmarkKinds;
import 'mapping_api.dart';

enum _Mode { view, drawBoundary, drawZone, walking }

const _sideColors = [
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFFD81B60),
];

Color sideColor(int seq) => _sideColors[seq % _sideColors.length];

/// Around Ozhar (Jawhar, Palghar), used until there is a boundary or a GPS fix.
const _defaultCenter = LatLng(19.912, 73.226);

class BoundaryScreen extends StatefulWidget {
  const BoundaryScreen({super.key, required this.caseId, required this.canEdit});

  final String caseId;

  /// Claimant while drafting, or the Gram Sabha while it reviews.
  final bool canEdit;

  @override
  State<BoundaryScreen> createState() => _BoundaryScreenState();
}

class _BoundaryScreenState extends State<BoundaryScreen> {
  final _api = MappingApi();
  final _map = MapController();

  bool _loading = true;
  Object? _error;
  Map<String, dynamic>? _boundary;
  List<Map<String, dynamic>> _walks = [];
  List<Map<String, dynamic>> _disputes = [];

  bool _satellite = false;
  _Mode _mode = _Mode.view;
  final List<LatLng> _draft = [];
  final List<double?> _draftAccuracy = [];
  String _draftSource = 'sketch_digitised';
  List<LatLng>? _lastWalkTrace;
  StreamSubscription? _walkSub;
  LatLng? _me;
  bool _saving = false;

  bool get _frozen => _boundary != null && _boundary!['status'] != 'draft';
  bool get _editable => widget.canEdit && !_frozen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _walkSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.boundary(widget.caseId),
        _api.walks(widget.caseId),
        _api.disputes(widget.caseId),
      ]);
      if (!mounted) return;
      setState(() {
        _boundary = results[0] as Map<String, dynamic>?;
        _walks = results[1] as List<Map<String, dynamic>>;
        _disputes = results[2] as List<Map<String, dynamic>>;
        _error = null;
        _loading = false;
      });
      _fitToBoundary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<LatLng> get _savedRing => outerRing(_boundary?['geometry'] as Map<String, dynamic>?);

  void _fitToBoundary() {
    final ring = _savedRing;
    if (ring.length < 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(ring),
          padding: const EdgeInsets.all(36),
          maxZoom: 18,
        ));
      } catch (_) {/* map not laid out yet */}
    });
  }

  // ── Tools ──────────────────────────────────────────────────────────────────

  void _toggleBasemap() => setState(() => _satellite = !_satellite);

  Future<void> _centerOnMe() async {
    try {
      final p = await currentPosition();
      if (!mounted) return;
      final here = LatLng(p.latitude, p.longitude);
      setState(() => _me = here);
      _map.move(here, 17);
    } catch (e) {
      if (mounted) _snack(e is GpsUnavailable ? e.message : 'Could not get your location.');
    }
  }

  void _startDrawing(_Mode target) {
    setState(() {
      _mode = target;
      _draft.clear();
      _draftAccuracy.clear();
      _draftSource = 'sketch_digitised';
    });
    _snack(target == _Mode.drawBoundary
        ? 'Tap the map at each corner of the boundary, in order.'
        : 'Tap the map at each corner of the use zone.');
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (_mode != _Mode.drawBoundary && _mode != _Mode.drawZone) return;
    setState(() {
      _draft.add(point);
      _draftAccuracy.add(null);
    });
  }

  Future<void> _startGpsWalk() async {
    try {
      final stream = await positionStream(distanceFilterM: 5);
      setState(() {
        _mode = _Mode.walking;
        _draft.clear();
        _draftAccuracy.clear();
        _draftSource = 'gps_walk';
      });
      _walkSub = stream.listen((p) {
        if (!mounted) return;
        final here = LatLng(p.latitude, p.longitude);
        setState(() {
          _me = here;
          _draft.add(here);
          _draftAccuracy.add(p.accuracy);
        });
        _map.move(here, _map.camera.zoom < 16 ? 17 : _map.camera.zoom);
      }, onError: (_) => _snack('GPS signal lost.'));
    } catch (e) {
      _snack(e is GpsUnavailable ? e.message : 'Could not start GPS.');
    }
  }

  void _stopGpsWalk() {
    _walkSub?.cancel();
    _walkSub = null;
    setState(() {
      _lastWalkTrace = List.of(_draft);
      _mode = _Mode.drawBoundary; // review the walked points, then save
    });
    _snack('Walk stopped: ${_draft.length} points. Check them and save the boundary.');
  }

  void _undoPoint() {
    if (_draft.isEmpty) return;
    setState(() {
      _draft.removeLast();
      _draftAccuracy.removeLast();
    });
  }

  void _clearPoints() => setState(() {
        _draft.clear();
        _draftAccuracy.clear();
      });

  void _cancelDrawing() {
    _walkSub?.cancel();
    _walkSub = null;
    setState(() {
      _mode = _Mode.view;
      _draft.clear();
      _draftAccuracy.clear();
    });
  }

  Future<void> _finishDrawing() async {
    if (_draft.length < 3) {
      _snack('At least 3 points are needed.');
      return;
    }
    if (_mode == _Mode.drawZone) {
      await _saveUseZone();
    } else {
      await _saveBoundary();
    }
  }

  Future<void> _saveBoundary() async {
    if (_boundary != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save as a new version?'),
          content: const Text(
              'The earlier boundary is kept as an older version. Landmarks and use zones carry over where their side still exists.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _api.saveBoundary(
        widget.caseId,
        points: List.of(_draft),
        source: _draftSource,
        accuracyM: _draftSource == 'gps_walk' ? List.of(_draftAccuracy) : null,
      );
      if (!mounted) return;
      final opened = (saved['open_disputes'] as int?) ?? 0;
      setState(() {
        _mode = _Mode.view;
        _draft.clear();
        _draftAccuracy.clear();
      });
      showDone(context,
          'Boundary saved: ${saved['area_ha']} ha in ${(saved['segments'] as List).length} sides.');
      if (opened > 0) {
        _snack('This boundary overlaps a neighbouring claim. A dispute was opened [Rule 12(3)].');
      }
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveUseZone() async {
    final details = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.bottomSheetBg,
      builder: (_) => const _UseZoneSheet(),
    );
    if (details == null) return;
    setState(() => _saving = true);
    try {
      await _api.addUseZone(widget.caseId,
          useType: details.$1, name: details.$2, season: details.$3, points: List.of(_draft));
      if (!mounted) return;
      setState(() {
        _mode = _Mode.view;
        _draft.clear();
        _draftAccuracy.clear();
      });
      showDone(context, 'Use zone saved.');
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addLandmark() async {
    final segments = (_boundary?['segments'] as List<dynamic>? ?? []);
    if (segments.isEmpty) {
      _snack('Save the boundary first.');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.bottomSheetBg,
      builder: (_) => _LandmarkSheet(
        caseId: widget.caseId,
        segments: segments.cast<Map<String, dynamic>>(),
        mapCentre: () => _map.camera.center,
      ),
    );
    if (saved == true) {
      if (mounted) showDone(context, 'Landmark pinned.');
      _load();
    }
  }

  Future<void> _recordWalk() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.bottomSheetBg,
      builder: (_) => _WalkSheet(caseId: widget.caseId, trace: _lastWalkTrace),
    );
    if (saved == true) {
      if (mounted) showDone(context, 'Boundary walk recorded.');
      _load();
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'My Claims', 'Boundary'],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: VillagerEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load the boundary',
                    message: apiErrorText(_error!),
                    actionLabel: 'Try again',
                    actionIcon: Icons.refresh_rounded,
                    onAction: _load,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, box) => Column(
                    children: [
                      SizedBox(height: box.maxHeight * 0.5, child: _mapView()),
                      Expanded(child: _panel()),
                    ],
                  ),
                ),
    );
  }

  Widget _mapView() {
    final segments = (_boundary?['segments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final landmarks = (_boundary?['landmarks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final zones = (_boundary?['use_zones'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final ring = _savedRing;
    final drawing = _mode != _Mode.view;
    final draftColor = _mode == _Mode.drawZone ? const Color(0xFF8E24AA) : const Color(0xFFFF7A00);

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: ring.isNotEmpty ? ring.first : _defaultCenter,
            initialZoom: 15,
            maxZoom: 20,
            onTap: _onMapTap,
          ),
          children: [
            TileLayer(
              urlTemplate: _satellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxNativeZoom: _satellite ? 17 : 19,
              userAgentPackageName: 'org.vanmitra.app',
            ),
            PolygonLayer(polygons: [
              if (ring.length >= 3)
                Polygon(
                  points: ring,
                  isFilled: true,
                  color: const Color(0xFF2E705B).withValues(alpha: 0.16),
                  borderStrokeWidth: 0,
                ),
              for (final z in zones)
                if (outerRing(z['geometry'] as Map<String, dynamic>?).length >= 3)
                  Polygon(
                    points: outerRing(z['geometry'] as Map<String, dynamic>?),
                    isFilled: true,
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.18),
                    borderColor: const Color(0xFF8E24AA),
                    borderStrokeWidth: 1.5,
                    isDotted: true,
                  ),
              if (drawing && _draft.length >= 3)
                Polygon(
                  points: _draft,
                  isFilled: true,
                  color: draftColor.withValues(alpha: 0.15),
                  borderStrokeWidth: 0,
                ),
            ]),
            PolylineLayer(polylines: [
              for (final s in segments)
                Polyline(
                  points: lineString(s['geometry'] as Map<String, dynamic>?),
                  color: sideColor(s['seq'] as int),
                  strokeWidth: 4.5,
                ),
              if (drawing && _draft.length >= 2)
                Polyline(
                  points: [..._draft, if (_mode != _Mode.walking && _draft.length >= 3) _draft.first],
                  color: draftColor,
                  strokeWidth: 3,
                  isDotted: _mode != _Mode.walking,
                ),
            ]),
            MarkerLayer(markers: [
              for (final l in landmarks)
                Marker(
                  point: LatLng((l['lat'] as num).toDouble(), (l['lon'] as num).toDouble()),
                  width: 34,
                  height: 34,
                  alignment: Alignment.topCenter,
                  child: Tooltip(
                    message: l['name'] as String,
                    child: Icon(Icons.location_on_rounded,
                        size: 34, color: sideColor(l['segment_seq'] as int)),
                  ),
                ),
              if (drawing)
                for (final p in _draft)
                  Marker(
                    point: p,
                    width: 12,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: draftColor, width: 3),
                      ),
                    ),
                  ),
              if (_me != null)
                Marker(
                  point: _me!,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x551976D2), blurRadius: 8)],
                    ),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              _mapButton(_satellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                  _satellite ? 'Street map' : 'Satellite', _toggleBasemap),
              const SizedBox(height: 8),
              _mapButton(Icons.my_location_rounded, 'My location', _centerOnMe),
              if (ring.length >= 3) ...[
                const SizedBox(height: 8),
                _mapButton(Icons.fit_screen_rounded, 'Show whole boundary', _fitToBoundary),
              ],
            ],
          ),
        ),
        if (drawing) Positioned(left: 10, right: 60, top: 10, child: _drawingBar(draftColor)),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _mapButton(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(
          tooltip: tip,
          icon: Icon(icon, color: const Color(0xFF143526)),
          onPressed: onTap,
        ),
      );

  Widget _drawingBar(Color color) {
    final walking = _mode == _Mode.walking;
    final lastAcc = _draftAccuracy.isNotEmpty ? _draftAccuracy.last : null;
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              walking
                  ? 'Walking the boundary · ${_draft.length} points${lastAcc != null ? ' · ±${lastAcc.toStringAsFixed(0)} m' : ''}'
                  : '${_mode == _Mode.drawZone ? 'Use zone' : 'Boundary'} · ${_draft.length} points',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (walking)
                  _barButton(Icons.stop_circle_rounded, 'Stop', _stopGpsWalk)
                else ...[
                  _barButton(Icons.undo_rounded, 'Undo point', _draft.isEmpty ? null : _undoPoint),
                  _barButton(Icons.clear_all_rounded, 'Clear', _draft.isEmpty ? null : _clearPoints),
                  _barButton(Icons.check_circle_rounded, 'Save', _draft.length < 3 ? null : _finishDrawing),
                ],
                _barButton(Icons.close_rounded, 'Cancel', _cancelDrawing),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barButton(IconData icon, String label, VoidCallback? onTap) => TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          foregroundColor: const Color(0xFF143526),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _panel() {
    final b = _boundary;
    final segments = (b?['segments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final landmarks = (b?['landmarks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final zones = (b?['use_zones'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final openDisputes = _disputes.where((d) => d['is_open'] == true).toList();
    final c = context.colors;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          if (b == null)
            VmCard(
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2E705B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.canEdit
                          ? 'No boundary yet. Walk it with GPS, or draw it by tapping the corners on the map.'
                          : 'No boundary has been mapped for this claim yet.',
                      style: TextStyle(color: c.textPrimary, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            )
          else
            _summary(b, segments.length, openDisputes.length),
          if (_frozen) ...[
            const SizedBox(height: 10),
            const StatusPill(
                label: 'Approved by the Gram Sabha: the boundary is frozen',
                color: Color(0xFF2E7D32),
                icon: Icons.lock_rounded),
          ],
          if (_editable && _mode == _Mode.view) ...[
            const SizedBox(height: 16),
            const VmSectionTitle('Map tools'),
            _tools(b != null),
          ],
          if (openDisputes.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final d in openDisputes) _disputeCard(d),
          ],
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const VmSectionTitle('Sides of the boundary', subtitle: 'Every side needs at least one landmark.'),
            for (final s in segments) _sideRow(s),
          ],
          if (landmarks.isNotEmpty) ...[
            const SizedBox(height: 16),
            VmSectionTitle('Landmarks', trailing: Text('${landmarks.length}')),
            for (final l in landmarks) _landmarkRow(l),
          ],
          if (zones.isNotEmpty) ...[
            const SizedBox(height: 16),
            VmSectionTitle('Use zones', trailing: Text('${zones.length}')),
            for (final z in zones) _zoneRow(z),
          ],
          const SizedBox(height: 16),
          VmSectionTitle('Boundary walks with elders', trailing: Text('${_walks.length}')),
          if (_walks.isEmpty)
            Text('No walk recorded yet.', style: TextStyle(color: c.textSecondary, fontSize: 13))
          else
            for (final w in _walks) _walkRow(w),
        ],
      ),
    );
  }

  Widget _summary(Map<String, dynamic> b, int sides, int disputes) {
    final missing = b['segments_without_landmark'] as int? ?? 0;
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 11.5)),
            ],
          ),
        );
    return VmCard(
      child: Column(
        children: [
          Row(
            children: [
              stat('${b['area_ha']}', 'hectares', const Color(0xFF143526)),
              stat('$sides', 'sides', const Color(0xFF1E6FB8)),
              stat('$missing', 'sides without\na landmark',
                  missing == 0 ? const Color(0xFF2E7D32) : const Color(0xFFE07A00)),
              stat('$disputes', 'open\ndisputes',
                  disputes == 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Version ${b['version']} · ${b['source'] == 'gps_walk' ? 'walked with GPS' : 'drawn on the map'}',
            style: TextStyle(color: context.colors.textTertiary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _tools(bool hasBoundary) {
    final tools = [
      (Icons.directions_walk_rounded, 'Walk with GPS', const Color(0xFF2E705B), _startGpsWalk),
      (Icons.draw_rounded, 'Draw on map', const Color(0xFF1E6FB8), () => _startDrawing(_Mode.drawBoundary)),
      (Icons.add_location_alt_rounded, 'Add landmark', const Color(0xFFFF7A00),
          hasBoundary ? _addLandmark : null),
      (Icons.layers_rounded, 'Add use zone', const Color(0xFF8E24AA),
          hasBoundary ? () => _startDrawing(_Mode.drawZone) : null),
      (Icons.groups_rounded, 'Record boundary walk', const Color(0xFF6D4C41), _recordWalk),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final (icon, label, color, onTap) in tools)
          Opacity(
            opacity: onTap == null ? 0.45 : 1,
            child: VmCard(
              padding: const EdgeInsets.all(8),
              radius: 16,
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sideRow(Map<String, dynamic> s) {
    final seq = s['seq'] as int;
    final count = s['landmark_count'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VmCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 14,
        child: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: sideColor(seq), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Side ${seq + 1} · ${((s['length_m'] as num?) ?? 0).toStringAsFixed(0)} m',
                  style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700)),
            ),
            count == 0
                ? const StatusPill(label: 'No landmark yet', color: Color(0xFFE07A00), icon: Icons.warning_amber_rounded)
                : StatusPill(
                    label: '$count landmark${count == 1 ? '' : 's'}',
                    color: const Color(0xFF2E7D32),
                    icon: Icons.check_rounded),
          ],
        ),
      ),
    );
  }

  Widget _landmarkRow(Map<String, dynamic> l) {
    final photo = l['photo_media_id'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VmCard(
        padding: const EdgeInsets.all(10),
        radius: 14,
        onTap: () => _map.move(LatLng((l['lat'] as num).toDouble(), (l['lon'] as num).toDouble()), 18),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: photo != null
                    ? MediaImage(mediaId: photo, fit: BoxFit.cover)
                    : Container(
                        color: sideColor(l['segment_seq'] as int).withValues(alpha: 0.12),
                        child: Icon(Icons.location_on_rounded, color: sideColor(l['segment_seq'] as int)),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l['name'] as String,
                      style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700)),
                  Text(
                    '${kLandmarkKinds[l['kind']] ?? l['kind']} · Side ${(l['segment_seq'] as int) + 1} · ${((l['distance_to_segment_m'] as num?) ?? 0).toStringAsFixed(0)} m from the line',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoneRow(Map<String, dynamic> z) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: VmCard(
          padding: const EdgeInsets.all(12),
          radius: 14,
          child: Row(
            children: [
              const Icon(Icons.layers_rounded, color: Color(0xFF8E24AA)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(z['name'] as String? ?? kUseZoneTypes[z['use_type']] ?? '',
                        style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                      '${kUseZoneTypes[z['use_type']] ?? z['use_type']} · ${z['area_ha']} ha'
                      '${z['season'] != null ? ' · ${z['season']}' : ''}',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (z['within_boundary'] == false)
                const StatusPill(label: 'Outside boundary', color: Color(0xFFE07A00)),
            ],
          ),
        ),
      );

  Widget _walkRow(Map<String, dynamic> w) {
    final people = (w['participants'] as List<dynamic>? ?? []);
    final date = DateTime.tryParse(w['walked_on'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VmCard(
        padding: const EdgeInsets.all(12),
        radius: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hiking_rounded, color: Color(0xFF6D4C41)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date != null ? DateFormat('d MMM yyyy').format(date) : '',
                      style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700)),
                  Text(people.map((p) => (p as Map)['name']).join(', '),
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                  if (w['notes'] != null)
                    Text(w['notes'] as String,
                        style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            if (w['trace_length_m'] != null)
              Text('${((w['trace_length_m'] as num) / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(color: Color(0xFF6D4C41), fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _disputeCard(Map<String, dynamic> d) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: VmCard(
          borderColor: const Color(0xFFEF9A9A),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_rounded, color: Color(0xFFC62828)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${d['overlap_ha']} ha overlaps the claim of ${d['neighbour_village']}. '
                  'A boundary dispute is open; the two Gram Sabhas meet to settle it [Rule 12(3)].',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Sheets ────────────────────────────────────────────────────────────────────

InputDecoration _input(BuildContext context, {String? hint, String? label}) => InputDecoration(
      hintText: hint,
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: context.colors.isDark ? const Color(0xFF16251D) : const Color(0xFFF5FBF7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

Widget _sheetTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
    );

class _LandmarkSheet extends StatefulWidget {
  const _LandmarkSheet({required this.caseId, required this.segments, required this.mapCentre});

  final String caseId;
  final List<Map<String, dynamic>> segments;
  final LatLng Function() mapCentre;

  @override
  State<_LandmarkSheet> createState() => _LandmarkSheetState();
}

class _LandmarkSheetState extends State<_LandmarkSheet> {
  final _name = TextEditingController();
  late int _segment = widget.segments
      .firstWhere((s) => (s['landmark_count'] as int? ?? 0) == 0, orElse: () => widget.segments.first)['seq'] as int;
  String _kind = 'stream';
  bool _useGps = true;
  LatLng? _gps;
  double? _gpsAccuracy;
  PickedImage? _photo;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await currentPosition();
      if (mounted) {
        setState(() {
          _gps = LatLng(p.latitude, p.longitude);
          _gpsAccuracy = p.accuracy;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _useGps = false);
    }
  }

  Future<void> _takePhoto() async {
    final f = await pickImageFile(ImageSource.camera);
    if (f != null && mounted) setState(() => _photo = f);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the landmark a name, e.g. नागदेवता नाला.');
      return;
    }
    final at = _useGps ? _gps : widget.mapCentre();
    if (at == null) {
      setState(() => _error = 'No GPS position yet; use the map centre instead.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? photoId;
      if (_photo != null) {
        final m = await EvidenceApi().uploadMedia(
          bytes: _photo!.bytes,
          filename: _photo!.name,
          mime: _photo!.mime,
          lat: at.latitude,
          lon: at.longitude,
          accuracyM: _useGps ? _gpsAccuracy : null,
          capturedAt: DateTime.now(),
        );
        photoId = m['id'] as String;
      }
      await MappingApi().addLandmark(widget.caseId,
          segmentSeq: _segment, name: _name.text.trim(), kind: _kind, at: at, photoMediaId: photoId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetTitle(context, 'Pin a landmark · खूण'),
            DropdownButtonFormField<int>(
              value: _segment,
              isExpanded: true,
              decoration: _input(context, label: 'Which side?'),
              items: [
                for (final s in widget.segments)
                  DropdownMenuItem(
                    value: s['seq'] as int,
                    child: Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: sideColor(s['seq'] as int), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Side ${(s['seq'] as int) + 1} · ${s['landmark_count']} landmark(s)'),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _segment = v ?? _segment),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _kind,
              isExpanded: true,
              decoration: _input(context, label: 'Kind of landmark'),
              items: [
                for (final k in kLandmarkKinds.entries) DropdownMenuItem(value: k.key, child: Text(k.value)),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: _input(context, label: 'Name', hint: 'e.g. Nagdevta stream')),
            const SizedBox(height: 12),
            Text('Where is it?', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            RadioListTile<bool>(
              value: true,
              groupValue: _useGps,
              onChanged: (v) => setState(() => _useGps = true),
              contentPadding: EdgeInsets.zero,
              title: const Text('Here, where I am standing'),
              subtitle: Text(_gps == null
                  ? 'Getting GPS…'
                  : '${_gps!.latitude.toStringAsFixed(5)}, ${_gps!.longitude.toStringAsFixed(5)} (±${_gpsAccuracy?.toStringAsFixed(0)} m)'),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: _useGps,
              onChanged: (v) => setState(() => _useGps = false),
              contentPadding: EdgeInsets.zero,
              title: const Text('At the centre of the map'),
              subtitle: const Text('Close this, move the map over the place, and add again.'),
            ),
            Row(
              children: [
                if (_photo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_photo!.bytes, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: Text(_photo == null ? 'Add a photo (optional)' : 'Retake photo'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            OrangePillButton(label: 'Pin landmark', icon: Icons.add_location_alt_rounded, busy: _busy, expand: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _UseZoneSheet extends StatefulWidget {
  const _UseZoneSheet();

  @override
  State<_UseZoneSheet> createState() => _UseZoneSheetState();
}

class _UseZoneSheetState extends State<_UseZoneSheet> {
  String _type = 'grazing';
  final _name = TextEditingController();
  final _season = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _season.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetTitle(context, 'What is this area used for?'),
            DropdownButtonFormField<String>(
              value: _type,
              isExpanded: true,
              decoration: _input(context, label: 'Use'),
              items: [for (final t in kUseZoneTypes.entries) DropdownMenuItem(value: t.key, child: Text(t.value))],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: _input(context, label: 'Name (optional)', hint: 'e.g. Gavthan charai')),
            const SizedBox(height: 12),
            TextField(controller: _season, decoration: _input(context, label: 'Season (optional)', hint: 'e.g. Monsoon')),
            const SizedBox(height: 16),
            OrangePillButton(
              label: 'Save use zone',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () => Navigator.pop(context, (_type, _name.text.trim(), _season.text.trim())),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkSheet extends StatefulWidget {
  const _WalkSheet({required this.caseId, this.trace});

  final String caseId;
  final List<LatLng>? trace;

  @override
  State<_WalkSheet> createState() => _WalkSheetState();
}

class _WalkSheetState extends State<_WalkSheet> {
  DateTime _date = DateTime.now();
  final _names = TextEditingController();
  final _notes = TextEditingController();
  String _role = 'elder';
  bool _attachTrace = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _names.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final names = _names.text.split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) {
      setState(() => _error = 'Write the names of the people who walked the boundary.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MappingApi().recordWalk(
        widget.caseId,
        walkedOn: _date,
        participants: [for (final n in names) {'name': n, 'role': _role}],
        trace: _attachTrace ? widget.trace : null,
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetTitle(context, 'Boundary walk with elders'),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded),
              label: Text('Walked on ${DateFormat('d MMM yyyy').format(_date)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _names,
              maxLines: 4,
              decoration: _input(context, label: 'Who walked (one name per line)'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final r in const [('elder', 'Elders'), ('frc', 'FRC'), ('member', 'Members'), ('other', 'Others')])
                  ChoiceChip(label: Text(r.$2), selected: _role == r.$1, onSelected: (_) => setState(() => _role = r.$1)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 2, decoration: _input(context, label: 'Notes (optional)')),
            if (widget.trace != null && widget.trace!.length >= 2)
              SwitchListTile(
                value: _attachTrace,
                onChanged: (v) => setState(() => _attachTrace = v),
                contentPadding: EdgeInsets.zero,
                title: Text('Attach the GPS walk just made (${widget.trace!.length} points)'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            OrangePillButton(label: 'Record walk', icon: Icons.check_rounded, busy: _busy, expand: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
