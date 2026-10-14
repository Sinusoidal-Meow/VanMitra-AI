// What the landowner tells us. It mirrors the backend's ProfileIn exactly (docs/BACKEND_PLAN.md
// §3): every field is optional, and there is no caste, income or ID number anywhere (rule L8).
// Everything here is shown back as "Told by you, not verified".

enum AreaUnit {
  hectare('hectare'),
  acre('acre'),
  guntha('guntha');

  const AreaUnit(this.wire);
  final String wire;

  /// 1 acre = 0.40468564224 ha; 40 guntha = 1 acre (Maharashtra land units).
  double get toHectaresFactor => switch (this) {
        AreaUnit.hectare => 1.0,
        AreaUnit.acre => _acreToHa,
        AreaUnit.guntha => _acreToHa / 40,
      };
}

const double _acreToHa = 0.40468564224;

/// Above this the form asks "please check the number". It never blocks.
const double kWarnAboveHectares = 100;

enum LandType {
  irrigated('irrigated'),
  rainFed('rain_fed'),
  mixed('mixed');

  const LandType(this.wire);
  final String wire;
}

enum WaterOnLand {
  openWell('open_well'),
  borewell('borewell'),
  none('none');

  const WaterOnLand(this.wire);
  final String wire;
}

enum MoneyLevel {
  low('low'),
  medium('medium'),
  high('high');

  const MoneyLevel(this.wire);
  final String wire;
}

enum LocationSource {
  gps('gps'),
  manual('manual'),
  villageCentre('village_centre');

  const LocationSource(this.wire);
  final String wire;
}

// The controlled vocabularies. The server validates them too; they live here so the form works
// offline. (Later they can come from GET /livelihood/meta.)
const List<String> kAnimalCodes = [
  'cow',
  'buffalo',
  'bullock',
  'goat_sheep',
  'poultry',
  'other',
];
const List<String> kAssetCodes = [
  'well',
  'borewell',
  'farm_pond',
  'shed',
  'pump',
  'drip_kit',
  'bullock_cart',
  'storage_room',
  'vehicle',
  'fodder_land',
  'other',
];
const List<String> kPastWorkCodes = [
  'paddy',
  'millets',
  'pulses',
  'vegetables',
  'fruit',
  'dairy',
  'goat_rearing',
  'poultry',
  'forest_produce',
  'labour',
  'other',
];

/// A rough box around Maharashtra: lat 15.5-22.1, lng 72.5-80.95. The same sanity check the
/// server makes, so a typo is caught before it is sent.
bool insideMaharashtra(double lat, double lng) =>
    lat >= 15.5 && lat <= 22.1 && lng >= 72.5 && lng <= 80.95;

class LivelihoodProfile {
  const LivelihoodProfile({
    this.areaValue,
    this.areaUnit = AreaUnit.hectare,
    this.landType,
    this.waterOnLand,
    this.lat,
    this.lng,
    this.accuracyM,
    this.locationSource,
    this.livestock = const {},
    this.assets = const {},
    this.pastWork = const {},
    this.familyWorkers,
    this.moneyLevel,
  });

  final double? areaValue;
  final AreaUnit areaUnit;
  final LandType? landType;
  final WaterOnLand? waterOnLand;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final LocationSource? locationSource;
  final Map<String, int> livestock; // only animals he has (> 0)
  final Set<String> assets;
  final Set<String> pastWork;
  final int? familyWorkers;
  final MoneyLevel? moneyLevel;

  /// Land in hectares, or null if he gave none.
  double? get areaHa =>
      areaValue == null ? null : areaValue! * areaUnit.toHectaresFactor;

  bool get hasDetails =>
      areaValue != null ||
      livestock.isNotEmpty ||
      assets.isNotEmpty ||
      pastWork.isNotEmpty ||
      moneyLevel != null ||
      (familyWorkers ?? 0) > 0;

  /// The request body for PUT /livelihood/profile. Unset fields are left out; the server treats
  /// a missing field as "not answered".
  Map<String, dynamic> toJson() {
    final land = <String, dynamic>{
      if (areaValue != null) ...{
        'area_value': areaValue,
        'area_unit': areaUnit.wire,
      },
      if (landType != null) 'land_type': landType!.wire,
      if (waterOnLand != null) 'water_on_land': waterOnLand!.wire,
    };
    return {
      if (land.isNotEmpty) 'land': land,
      if (lat != null && lng != null && locationSource != null)
        'location': {
          'lat': lat,
          'lng': lng,
          if (accuracyM != null) 'accuracy_m': accuracyM,
          'source': locationSource!.wire,
        },
      if (livestock.isNotEmpty) 'livestock': livestock,
      if (assets.isNotEmpty) 'assets': assets.toList()..sort(),
      if (pastWork.isNotEmpty) 'past_work': pastWork.toList()..sort(),
      if (familyWorkers != null) 'family_workers': familyWorkers,
      if (moneyLevel != null) 'money_level': moneyLevel!.wire,
    };
  }

  /// Read back what the server (or the phone's cache) holds: the `profile` part of ProfileOut.
  factory LivelihoodProfile.fromJson(Map<String, dynamic> j) {
    final land = (j['land'] as Map<String, dynamic>?) ?? const {};
    final loc = j['location'] as Map<String, dynamic>?;
    T? byWire<T>(List<T> values, Object? raw, String Function(T) wire) {
      for (final v in values) {
        if (wire(v) == raw) return v;
      }
      return null;
    }

    return LivelihoodProfile(
      areaValue: (land['area_value'] as num?)?.toDouble(),
      areaUnit: byWire(AreaUnit.values, land['area_unit'], (v) => v.wire) ??
          AreaUnit.hectare,
      landType: byWire(LandType.values, land['land_type'], (v) => v.wire),
      waterOnLand: byWire(
        WaterOnLand.values,
        land['water_on_land'],
        (v) => v.wire,
      ),
      lat: (loc?['lat'] as num?)?.toDouble(),
      lng: (loc?['lng'] as num?)?.toDouble(),
      accuracyM: (loc?['accuracy_m'] as num?)?.toDouble(),
      locationSource: byWire(
        LocationSource.values,
        loc?['source'],
        (v) => v.wire,
      ),
      livestock: {
        for (final e
            in ((j['livestock'] as Map<String, dynamic>?) ?? const {}).entries)
          if ((e.value as num) > 0) e.key: (e.value as num).toInt(),
      },
      assets: Set<String>.from((j['assets'] as List?) ?? const []),
      pastWork: Set<String>.from((j['past_work'] as List?) ?? const []),
      familyWorkers: j['family_workers'] as int?,
      moneyLevel: byWire(MoneyLevel.values, j['money_level'], (v) => v.wire),
    );
  }
}
