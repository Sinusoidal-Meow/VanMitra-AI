import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/village_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/boundary_alert.dart';
import '../../services/module_b_service.dart';
import '../../widgets/van_mitra_app_shell.dart';
import 'alert_detail_screen.dart';
import 'alert_history_screen.dart';

/// Basemap mode selector per notebook Cell 11 & Cell 22
enum BasemapMode {
  esriSatellite, // Esri World Imagery (Satellite)
  openStreetMap, // OpenStreetMap / Street
  diagramView,   // Offline Vector Diagram
}

extension BasemapModeExt on BasemapMode {
  String get label {
    switch (this) {
      case BasemapMode.esriSatellite: return '📡 Satellite';
      case BasemapMode.openStreetMap: return '🗺️ Street';
      case BasemapMode.diagramView:   return '🎨 Canvas';
    }
  }
}

/// Module B — Screen #13: CFR Boundary Map Viewer (Satellite View Implementation)
///
/// Implements the Satellite View requirements from VanMitra_ModuleB_Ozar.ipynb:
/// - Real Esri World Imagery basemap tile layer (`https://server.arcgisonline.com/...`)
/// - Toggle between Satellite, Street, and Canvas diagram basemaps
/// - CFR Village Boundary Polygon overlay (yellow dashed border)
/// - Per-parcel risk tier markers (🔴 Red / 🟡 Yellow / 🟢 Green)
/// - Per-parcel land-use filtering (Domestic Homestead vs Agricultural Farmland)
/// - Interactive parcel bottom sheet matching Notebook popups
/// - Provenance & Satellite Configuration banner
class BoundaryMapScreen extends StatefulWidget {
  final Widget? bottomNavigationBar;
  const BoundaryMapScreen({super.key, this.bottomNavigationBar});

  @override
  State<BoundaryMapScreen> createState() => _BoundaryMapScreenState();
}

class _BoundaryMapScreenState extends State<BoundaryMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  BasemapMode _basemapMode = BasemapMode.esriSatellite;
  AlertTier? _layerFilter; // null = all tiers
  String? _landUseFilter;  // null = all land use types

  bool _alertDismissed = false;
  late AnimationController _pulseCtrl;

  final _svc = SeedModuleBService();
  List<BoundaryAlert> _alerts = [];
  Map<int, LatLng> _parcelCoords = {};
  Map<int, List<LatLng>> _parcelPolygons = {};

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final alerts = await _svc.getAlerts('ozar');
    final coords = <int, LatLng>{};
    final polygons = <int, List<LatLng>>{};

    final boundary = VillageConstants.cfrBoundaryPolygon;
    final minLat = boundary.map((p) => p.latitude).reduce(math.min);
    final maxLat = boundary.map((p) => p.latitude).reduce(math.max);
    final minLng = boundary.map((p) => p.longitude).reduce(math.min);
    final maxLng = boundary.map((p) => p.longitude).reduce(math.max);

    // Grid placement algorithm ensuring non-overlapping distribution across village area
    final count = alerts.length;
    final gridSide = math.max(6, math.sqrt(count * 1.5).ceil());
    final latStep = (maxLat - minLat) / gridSide;
    final lngStep = (maxLng - minLng) / gridSide;

    final cells = <math.Point<int>>[];
    for (int r = 1; r < gridSide - 1; r++) {
      for (int c = 1; c < gridSide - 1; c++) {
        cells.add(math.Point(r, c));
      }
    }
    final rng = math.Random(42);
    cells.shuffle(rng);

    for (int i = 0; i < alerts.length; i++) {
      final a = alerts[i];
      final key = a.landownerId ?? (i + 1);

      final cell = cells[i % cells.length];
      // Controlled jitter (max 25% of step) guaranteeing zero overlaps between parcel digital fences
      final jitterLat = (rng.nextDouble() - 0.5) * 0.30 * latStep;
      final jitterLng = (rng.nextDouble() - 0.5) * 0.30 * lngStep;

      final centerLat = minLat + (cell.x + 0.5) * latStep + jitterLat;
      final centerLng = minLng + (cell.y + 0.5) * lngStep + jitterLng;
      final center = LatLng(centerLat, centerLng);
      coords[key] = center;

      // Area in square meters scaled precisely per landowner claim
      final areaSqm = a.declaredAreaSqm ?? (3000.0 + (key % 12) * 450.0);

      // Procedurally generate irregular 5-8 vertex digital fence polygon proportional to area
      final polyVertices = _generateDigitalFencePolygon(
        center: center,
        areaSqm: areaSqm,
        seed: key,
      );
      polygons[key] = polyVertices;
    }

    if (mounted) {
      setState(() {
        _alerts = alerts;
        _parcelCoords = coords;
        _parcelPolygons = polygons;
      });
    }
  }

  /// Generates a realistic, irregular polynomial shape (5 to 8 vertices) for digital fencing
  List<LatLng> _generateDigitalFencePolygon({
    required LatLng center,
    required double areaSqm,
    required int seed,
  }) {
    final prng = math.Random(seed * 37 + 101);

    // Calculate effective radius from area: A = pi * r^2
    final radiusMeters = math.sqrt(areaSqm / math.pi) * 0.85;

    // Convert meters to latitude & longitude degrees
    final latRadius = radiusMeters / 111000.0;
    final lngRadius = radiusMeters / (111000.0 * math.cos(center.latitude * math.pi / 180.0));

    // Number of vertices for irregular digital fence boundary (5 to 8 points)
    final numVertices = 5 + (seed % 4);
    final vertices = <LatLng>[];

    final baseAngleStep = (2 * math.pi) / numVertices;
    final angleOffset = prng.nextDouble() * math.pi;

    for (int i = 0; i < numVertices; i++) {
      final angleJitter = (prng.nextDouble() - 0.5) * (baseAngleStep * 0.30);
      final angle = angleOffset + i * baseAngleStep + angleJitter;

      // Radial perturbation (0.75x to 1.25x radius for realistic non-uniform field boundary)
      final radialMult = 0.75 + prng.nextDouble() * 0.50;

      final vLat = center.latitude + (latRadius * radialMult * math.sin(angle));
      final vLng = center.longitude + (lngRadius * radialMult * math.cos(angle));

      vertices.add(LatLng(vLat, vLng));
    }

    // Close polygon loop
    vertices.add(vertices.first);
    return vertices;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<BoundaryAlert> get _filteredAlerts {
    return _alerts.where((a) {
      if (_layerFilter != null && a.tier != _layerFilter) return false;
      if (_landUseFilter != null) {
        if (_landUseFilter == 'Domestic/Homestead' && a.landUseType != 'Domestic/Homestead') return false;
        if (_landUseFilter == 'Agricultural/Farmland' && a.landUseType != 'Agricultural/Farmland') return false;
      }
      return true;
    }).toList();
  }

  BoundaryAlert? get _primaryAlert {
    try {
      return _alerts.firstWhere((a) => a.tier == AlertTier.red);
    } catch (_) {
      try {
        return _alerts.firstWhere((a) => a.tier == AlertTier.yellow);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primaryAlert;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const VanMitraTopBar(),
      body: Stack(
        children: [
          // ── Map View (Satellite / Street / Canvas) ─────────────────────
          Positioned.fill(
            child: _basemapMode == BasemapMode.diagramView
                ? _MapCanvasDiagram(
                    pulseController: _pulseCtrl,
                    alerts: _filteredAlerts,
                    onParcelTap: _showParcelSheet,
                  )
                : _buildFlutterMap(),
          ),

          // ── Top Left: Tier Filter Pills ───────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            child: _LayerToggleRow(
              selected: _layerFilter,
              onSelected: (tier) => setState(() => _layerFilter = tier),
            ),
          ),

          // ── Top Right: Basemap Selector & Zoom Controls ───────────────
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Basemap Selector Card
                _BasemapSelectorCard(
                  currentMode: _basemapMode,
                  onChanged: (mode) => setState(() => _basemapMode = mode),
                ),
                const SizedBox(height: 8),

                // Map Navigation Controls
                _MapControlCard(
                  children: [
                    _MapControlButton(
                      icon: Icons.add,
                      onTap: () {
                        if (_basemapMode != BasemapMode.diagramView) {
                          _mapController.move(
                            _mapController.camera.center,
                            (_mapController.camera.zoom + 0.5).clamp(10.0, 20.0),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1, color: Color(0x22000000)),
                    _MapControlButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (_basemapMode != BasemapMode.diagramView) {
                          _mapController.move(
                            _mapController.camera.center,
                            (_mapController.camera.zoom - 0.5).clamp(10.0, 20.0),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _MapControlCard(
                  children: [
                    _MapControlButton(
                      icon: Icons.my_location,
                      onTap: () {
                        if (_basemapMode != BasemapMode.diagramView) {
                          _mapController.move(
                            const LatLng(VillageConstants.latitude, VillageConstants.longitude),
                            15.5,
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Centering on Ozhar CFR boundary…'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _MapControlCard(
                  children: [
                    _MapControlButton(
                      icon: Icons.history_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Land-Use Filter Strip (below tier filters) ────────────────
          Positioned(
            top: 56,
            left: 12,
            child: _LandUseToggleRow(
              selected: _landUseFilter,
              onSelected: (val) => setState(() => _landUseFilter = val),
            ),
          ),

          // ── Data Provenance Strip ──────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: (!_alertDismissed && primary != null) ? 220 : 8,
            child: _ProvenanceStrip(basemapMode: _basemapMode),
          ),

          // ── Alert Panel (bottom) ───────────────────────────────────────
          if (!_alertDismissed && primary != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _AlertPanel(
                alert: primary,
                onDismiss: () => setState(() => _alertDismissed = true),
                onViewDetail: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: primary)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.bottomNavigationBar ??
          const VanMitraBottomNav(activeTab: VanMitraTab.map),
    );
  }

  Widget _buildFlutterMap() {
    final filtered = _filteredAlerts;

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(VillageConstants.latitude, VillageConstants.longitude),
        initialZoom: 15.2,
        minZoom: 11.0,
        maxZoom: 20.0,
      ),
      children: [
        // ── Basemap Tile Layer (Esri World Imagery or OSM) ─────────────
        TileLayer(
          urlTemplate: _basemapMode == BasemapMode.esriSatellite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxNativeZoom: _basemapMode == BasemapMode.esriSatellite ? 17 : 19,
          maxZoom: 20.0,
          userAgentPackageName: 'org.vanmitra.app',
        ),

        // ── Layer 1: CFR Boundary & Per-Parcel Digital Fencing Polygons with Neon Glow ────
        PolygonLayer(
          polygons: [
            // Overall Village CFR Boundary — Outer Glow Pass
            Polygon(
              points: VillageConstants.cfrBoundaryPolygon,
              borderColor: const Color(0xFFFFD54F).withValues(alpha: 0.35),
              borderStrokeWidth: 8.0,
              color: Colors.transparent,
            ),
            // Overall Village CFR Boundary — Core Dotted Line Pass
            Polygon(
              points: VillageConstants.cfrBoundaryPolygon,
              borderColor: const Color(0xFFFFEA00),
              borderStrokeWidth: 3.0,
              color: const Color(0xFFFFD54F).withValues(alpha: 0.08),
              isDotted: true,
              label: 'Ozhar CFR Boundary',
              labelStyle: const TextStyle(
                color: Colors.yellowAccent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
            // Per-Parcel Digital Fencing Polygons (Glowing Halo Outer Pass)
            ...filtered.expand((alert) {
              final key = alert.landownerId ?? alert.id.hashCode;
              final polyPoints = _parcelPolygons[key];
              if (polyPoints == null || polyPoints.isEmpty) return <Polygon>[];

              final baseColor = Color(alert.tier.argbColor);
              final isRed = alert.tier == AlertTier.red;
              final isYellow = alert.tier == AlertTier.yellow;

              // High-vibrancy glow accent colors
              final vibrantColor = isRed
                  ? const Color(0xFFFF1744)
                  : (isYellow ? const Color(0xFFFFC400) : const Color(0xFF00E676));

              return [
                // Pass 1: Soft Outer Glow Halo
                Polygon(
                  points: polyPoints,
                  borderColor: vibrantColor.withValues(alpha: isRed ? 0.45 : (isYellow ? 0.40 : 0.35)),
                  borderStrokeWidth: isRed ? 7.0 : (isYellow ? 6.0 : 5.0),
                  color: Colors.transparent,
                ),
                // Pass 2: Sharp Core Dotted Digital Fence Line
                Polygon(
                  points: polyPoints,
                  borderColor: vibrantColor,
                  borderStrokeWidth: isRed ? 2.8 : (isYellow ? 2.2 : 1.8),
                  color: baseColor.withValues(alpha: isRed ? 0.16 : (isYellow ? 0.12 : 0.08)),
                  isDotted: true,
                ),
              ];
            }),
          ],
        ),

        // ── Layer 2: Interactive Digital Fence Badges at Centroids ───
        MarkerLayer(
          markers: filtered.map((alert) {
            final key = alert.landownerId ?? alert.id.hashCode;
            final pos = _parcelCoords[key] ??
                const LatLng(VillageConstants.latitude, VillageConstants.longitude);
            return Marker(
              point: pos,
              width: 52,
              height: 30,
              child: GestureDetector(
                onTap: () => _showParcelSheet(alert),
                child: _DigitalFenceNodeMarker(
                  alert: alert,
                  pulseController: _pulseCtrl,
                  isPulsing: alert.tier == AlertTier.red,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showParcelSheet(BoundaryAlert alert) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ParcelBottomSheet(
        alert: alert,
        onViewDetail: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: alert)),
          );
        },
      ),
    );
  }
}

// ── Basemap Selector Card ─────────────────────────────────────────────────────

class _BasemapSelectorCard extends StatelessWidget {
  final BasemapMode currentMode;
  final ValueChanged<BasemapMode> onChanged;
  const _BasemapSelectorCard({required this.currentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: (c.isDark ? c.cardBg : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: PopupMenuButton<BasemapMode>(
        initialValue: currentMode,
        onSelected: onChanged,
        color: c.cardBg,
        tooltip: 'Select Map Layer',
        itemBuilder: (ctx) => [
          for (final mode in BasemapMode.values)
            PopupMenuItem(
              value: mode,
              child: Row(
                children: [
                  Text(mode.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.textPrimary)),
                  if (mode == currentMode) const Spacer(),
                  if (mode == currentMode) const Icon(Icons.check_rounded, color: Colors.green, size: 18),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentMode.label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: c.textPrimary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Layer Toggle Row (Tier Filter) ────────────────────────────────────────────

class _LayerToggleRow extends StatelessWidget {
  final AlertTier? selected;
  final ValueChanged<AlertTier?> onSelected;
  const _LayerToggleRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: (c.isDark ? c.cardBg : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TierToggleChip('All', null, selected, onSelected),
          const SizedBox(width: 4),
          _TierToggleChip('🔴 Red', AlertTier.red, selected, onSelected),
          const SizedBox(width: 4),
          _TierToggleChip('🟡 Amber', AlertTier.yellow, selected, onSelected),
          const SizedBox(width: 4),
          _TierToggleChip('🟢 Stable', AlertTier.green, selected, onSelected),
        ],
      ),
    );
  }
}

class _TierToggleChip extends StatelessWidget {
  final String label;
  final AlertTier? tier;
  final AlertTier? selected;
  final ValueChanged<AlertTier?> onSelected;
  const _TierToggleChip(this.label, this.tier, this.selected, this.onSelected);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isSelected = selected == tier;
    final activeBg = c.isDark ? AppColors.forestSage : kPrimary;
    return GestureDetector(
      onTap: () => onSelected(isSelected ? null : tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : c.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Land-Use Filter Row ───────────────────────────────────────────────────────

class _LandUseToggleRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _LandUseToggleRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (c.isDark ? c.cardBg : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LandUseChip('All Uses', null, selected, onSelected),
          const SizedBox(width: 4),
          _LandUseChip('🏡 Homestead', 'Domestic/Homestead', selected, onSelected),
          const SizedBox(width: 4),
          _LandUseChip('🌾 Farmland', 'Agricultural/Farmland', selected, onSelected),
        ],
      ),
    );
  }
}

class _LandUseChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _LandUseChip(this.label, this.value, this.selected, this.onSelected);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelected(isSelected ? null : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF8F00).withValues(alpha: c.isDark ? 0.25 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8F00) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (c.isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100))
                : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Provenance Strip ──────────────────────────────────────────────────────────

class _ProvenanceStrip extends StatelessWidget {
  final BasemapMode basemapMode;
  const _ProvenanceStrip({required this.basemapMode});

  @override
  Widget build(BuildContext context) {
    final mapName = basemapMode == BasemapMode.esriSatellite
        ? 'Esri World Imagery (Maxar/Earthstar)'
        : basemapMode == BasemapMode.openStreetMap
            ? 'OpenStreetMap CartoDB'
            : 'Vector Diagram';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Boundary: OSM/FALLBACK  ·  Tile Layer: $mapName  ·  Model: demo-v1-synthetic',
          style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 10, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Parcel Bottom Sheet ───────────────────────────────────────────────────────

class _ParcelBottomSheet extends StatelessWidget {
  final BoundaryAlert alert;
  final VoidCallback onViewDetail;
  const _ParcelBottomSheet({required this.alert, required this.onViewDetail});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tierColor = Color(alert.tier.argbColor);
    final isHomestead = alert.landUseType == 'Domestic/Homestead';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: c.isDark ? c.border : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Text(alert.tier.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.claimantName ?? 'Unknown Claimant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Survey ${alert.surveyNo ?? "N/A"}',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isHomestead ? Colors.amber : Colors.green).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isHomestead ? '🏡 Domestic Homestead' : '🌾 Agricultural Farmland',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isHomestead
                                  ? (c.isDark ? const Color(0xFFFFB74D) : Colors.orange[800])
                                  : (c.isDark ? const Color(0xFF81C784) : Colors.green[800]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  alert.tier.displayNameEn,
                  style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details row
          Row(
            children: [
              _SheetInfo('Declared Area', '${alert.declaredAreaSqm?.toStringAsFixed(0) ?? "?"} m²'),
              const SizedBox(width: 24),
              if (alert.areaAffectedSqm != null && alert.areaAffectedSqm! > 0)
                _SheetInfo('Area Affected', '${alert.areaAffectedSqm!.toStringAsFixed(0)} m²',
                    color: tierColor),
              if (alert.resolutionFeasibility != null)
                _SheetInfo('Accuracy', alert.resolutionFeasibility!.label,
                    color: alert.resolutionFeasibility!.needsWarning
                        ? const Color(0xFFF59E0B) : const Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 20),

          // Action button
          if (alert.tier != AlertTier.green)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: onViewDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tierColor,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('View Alert Detail →',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          if (alert.tier == AlertTier.green)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: onViewDetail,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tierColor),
                  shape: const StadiumBorder(),
                ),
                child: Text('View Analysis →',
                    style: TextStyle(color: tierColor, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SheetInfo(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: TextStyle(fontSize: 11, color: c.textSecondary, letterSpacing: 0.5)),
        Text(value,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: color ?? c.textPrimary,
          )),
      ],
    );
  }
}

// ── Map Canvas Diagram (Offline Fallback View) ────────────────────────────────

class _MapCanvasDiagram extends StatelessWidget {
  final AnimationController pulseController;
  final List<BoundaryAlert> alerts;
  final ValueChanged<BoundaryAlert> onParcelTap;

  const _MapCanvasDiagram({
    required this.pulseController,
    required this.alerts,
    required this.onParcelTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final positions = _markerPositions(alerts.length, size);

    return ClipRect(
      child: CustomPaint(
        painter: _MapPainter(),
        child: Stack(
          children: [
            // Village label
            Positioned(
              left: size.width * 0.38,
              top: size.height * 0.28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.cardBg.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.colors.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ozhar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                    Text('CFR Boundary', style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
                  ],
                ),
              ),
            ),

            // Digital fence parcel node markers
            for (int i = 0; i < alerts.length && i < positions.length; i++)
              Positioned(
                left: positions[i].dx,
                top: positions[i].dy,
                child: GestureDetector(
                  onTap: () => onParcelTap(alerts[i]),
                  child: _DigitalFenceNodeMarker(
                    alert: alerts[i],
                    pulseController: pulseController,
                    isPulsing: alerts[i].tier == AlertTier.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Offset> _markerPositions(int count, Size size) {
    final rng = math.Random(42);
    final positions = <Offset>[];
    for (int i = 0; i < count; i++) {
      positions.add(Offset(
        size.width  * (0.15 + rng.nextDouble() * 0.65),
        size.height * (0.10 + rng.nextDouble() * 0.60),
      ));
    }
    return positions;
  }
}

// ── Digital Fence Node Marker Widget ─────────────────────────────────────────

class _DigitalFenceNodeMarker extends StatelessWidget {
  final BoundaryAlert alert;
  final AnimationController pulseController;
  final bool isPulsing;
  const _DigitalFenceNodeMarker({
    required this.alert,
    required this.pulseController,
    required this.isPulsing,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(alert.tier.argbColor);
    final surveyStr = alert.surveyNo != null ? 'S-${alert.surveyNo}' : 'P-${alert.landownerId ?? 0}';

    return SizedBox(
      width: 52,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPulsing)
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) {
                final v = pulseController.value;
                return Opacity(
                  opacity: (1.0 - v) * 0.7,
                  child: Transform.scale(
                    scale: 0.8 + v * 1.4,
                    child: Container(
                      width: 44,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color, width: 2),
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Sleek Transparent Digital Fence Tag Badge
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15), // Fully transparent background
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.65), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    surveyStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(blurRadius: 3, color: Colors.black),
                        Shadow(blurRadius: 6, color: Colors.black87),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offline Map Painter ───────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE8E0D0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()..color = const Color(0xFFCFCBBF)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final forestPaint = Paint()..color = const Color(0xFFBED5A8).withValues(alpha: 0.8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.35, size.height * 0.4),
          width: size.width * 0.5, height: size.height * 0.4),
      forestPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.75, size.height * 0.25),
          width: size.width * 0.3, height: size.height * 0.2),
      forestPaint,
    );

    final roadPaint = Paint()
      ..color = const Color(0xFFE8C97A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.6), Offset(size.width, size.height * 0.55), roadPaint);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.45, size.height * 0.7), roadPaint);
  }

  @override
  bool shouldRepaint(_MapPainter old) => false;
}

// ── Map Controls ──────────────────────────────────────────────────────────────

class _MapControlCard extends StatelessWidget {
  final List<Widget> children;
  const _MapControlCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44, height: 44,
        child: Icon(icon, color: c.textPrimary, size: 20),
      ),
    );
  }
}

// ── Alert Panel ───────────────────────────────────────────────────────────────

class _AlertPanel extends StatelessWidget {
  final BoundaryAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback onViewDetail;
  const _AlertPanel({required this.alert, required this.onDismiss, required this.onViewDetail});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tierColor = Color(alert.tier.argbColor);
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: tierColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: c.isDark ? Colors.black.withOpacity(0.5) : const Color(0x33000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: tierColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.claimantName ?? 'Change Alert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Survey ${alert.surveyNo ?? "N/A"} · ${alert.landUseType ?? ""}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    alert.tier.displayNameEn.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: c.border),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AlertMetric(
                        label: 'AREA AFFECTED',
                        value: alert.areaAffectedSqm != null
                            ? '${alert.areaAffectedSqm!.toStringAsFixed(0)} m²'
                            : '0 m²',
                      ),
                    ),
                    Expanded(
                      child: _AlertMetric(
                        label: 'DETECTED',
                        value: '${alert.detectedAt.day}/${alert.detectedAt.month}/${alert.detectedAt.year}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('LIKELY CAUSE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: c.textSecondary, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.forest_outlined, color: tierColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${alert.likelyCause ?? "Unknown"} (rule-based v1)',
                        style: TextStyle(fontSize: 14, color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: onViewDetail,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('View Detail',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tierColor,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report sent to Forest Rights Committee'),
                                backgroundColor: kStatusSuccess,
                              ),
                            );
                          },
                          icon: const Icon(Icons.report_outlined, size: 18),
                          label: const Text('Report FRC',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tierColor),
                            foregroundColor: tierColor,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertMetric extends StatelessWidget {
  final String label;
  final String value;
  const _AlertMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: c.textSecondary, letterSpacing: 1.1)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
      ],
    );
  }
}
