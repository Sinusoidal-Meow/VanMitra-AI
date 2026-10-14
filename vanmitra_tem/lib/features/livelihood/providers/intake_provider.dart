import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'profile_providers.dart';

const int kIntakeSteps =
    5; // land, animals, what he owns, past work and money, location

/// Default coordinates for the sample data (as he would type them).
const String kDefaultLatText = '19.7805';
const String kDefaultLngText = '73.2210';

class IntakeState {
  const IntakeState({
    this.step = 0,
    this.areaText = '',
    this.unit = AreaUnit.acre,
    this.landType,
    this.water,
    this.animals = const {},
    this.assets = const {},
    this.pastWork = const {},
    this.familyWorkers,
    this.money,
    this.source = LocationSource.villageCentre,
    this.latText = '',
    this.lngText = '',
    this.accuracyM,
    this.errorKey,
  });

  final int step;
  final String areaText;
  final AreaUnit unit;
  final LandType? landType;
  final WaterOnLand? water;
  final Map<String, int> animals;
  final Set<String> assets;
  final Set<String> pastWork;
  final int? familyWorkers;
  final MoneyLevel? money;
  final LocationSource source;
  final String latText;
  final String lngText;
  final double? accuracyM;

  /// A string key for the problem on the current step, or null.
  final String? errorKey;

  bool get isLast => step == kIntakeSteps - 1;

  static double? parseNumber(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  double? get areaValue => parseNumber(areaText);

  /// Land in hectares for the "≈ 1.2 hectares" line, or null.
  double? get areaHa {
    final v = areaValue;
    return v == null || v <= 0 ? null : v * unit.toHectaresFactor;
  }

  bool get areaLooksTooBig => (areaHa ?? 0) > kWarnAboveHectares;

  IntakeState copyWith({
    int? step,
    String? areaText,
    AreaUnit? unit,
    LandType? landType,
    bool clearLandType = false,
    WaterOnLand? water,
    bool clearWater = false,
    Map<String, int>? animals,
    Set<String>? assets,
    Set<String>? pastWork,
    int? familyWorkers,
    MoneyLevel? money,
    bool clearMoney = false,
    LocationSource? source,
    String? latText,
    String? lngText,
    double? accuracyM,
    bool clearAccuracy = false,
    String? errorKey,
    bool clearError = false,
  }) =>
      IntakeState(
        step: step ?? this.step,
        areaText: areaText ?? this.areaText,
        unit: unit ?? this.unit,
        landType: clearLandType ? null : (landType ?? this.landType),
        water: clearWater ? null : (water ?? this.water),
        animals: animals ?? this.animals,
        assets: assets ?? this.assets,
        pastWork: pastWork ?? this.pastWork,
        familyWorkers: familyWorkers ?? this.familyWorkers,
        money: clearMoney ? null : (money ?? this.money),
        source: source ?? this.source,
        latText: latText ?? this.latText,
        lngText: lngText ?? this.lngText,
        accuracyM: clearAccuracy ? null : (accuracyM ?? this.accuracyM),
        errorKey: clearError ? null : (errorKey ?? this.errorKey),
      );

  /// What to send and keep. Fields he left empty stay out.
  LivelihoodProfile toProfile() {
    final area = areaValue;
    final useLocation = source != LocationSource.villageCentre;
    return LivelihoodProfile(
      areaValue: area != null && area > 0 ? area : null,
      areaUnit: unit,
      landType: landType,
      waterOnLand: water,
      lat: useLocation ? parseNumber(latText) : null,
      lng: useLocation ? parseNumber(lngText) : null,
      accuracyM: useLocation && source == LocationSource.gps ? accuracyM : null,
      locationSource: source,
      livestock: {
        for (final e in animals.entries)
          if (e.value > 0) e.key: e.value,
      },
      assets: assets,
      pastWork: pastWork,
      familyWorkers: familyWorkers,
      moneyLevel: money,
    );
  }

  /// Start from what he saved before, so "Change my details" shows his answers.
  factory IntakeState.fromProfile(LivelihoodProfile? p) {
    if (p == null) return const IntakeState();
    String fmt(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toString();
    final located = p.lat != null &&
        p.lng != null &&
        p.locationSource != LocationSource.villageCentre;
    return IntakeState(
      areaText: p.areaValue == null ? '' : fmt(p.areaValue!),
      unit: p.areaUnit,
      landType: p.landType,
      water: p.waterOnLand,
      animals: p.livestock,
      assets: p.assets,
      pastWork: p.pastWork,
      familyWorkers: p.familyWorkers,
      money: p.moneyLevel,
      source: located
          ? (p.locationSource ?? LocationSource.manual)
          : LocationSource.villageCentre,
      latText: located ? p.lat!.toStringAsFixed(6) : '',
      lngText: located ? p.lng!.toStringAsFixed(6) : '',
      accuracyM: p.accuracyM,
    );
  }
}

class IntakeNotifier extends StateNotifier<IntakeState> {
  IntakeNotifier(super.initial);

  // land
  void setArea(String text) =>
      state = state.copyWith(areaText: text, clearError: true);
  void setUnit(AreaUnit unit) => state = state.copyWith(unit: unit);
  void setLandType(LandType? t) => state = t == null
      ? state.copyWith(clearLandType: true)
      : state.copyWith(landType: t);
  void setWater(WaterOnLand? w) => state =
      w == null ? state.copyWith(clearWater: true) : state.copyWith(water: w);

  // animals
  void setAnimal(String code, int count) {
    final next = Map<String, int>.from(state.animals);
    final clamped = count.clamp(0, 999);
    if (clamped == 0) {
      next.remove(code);
    } else {
      next[code] = clamped;
    }
    state = state.copyWith(animals: next);
  }

  // what he owns / past work
  void toggleAsset(String code) =>
      state = state.copyWith(assets: _toggled(state.assets, code));
  void togglePastWork(String code) =>
      state = state.copyWith(pastWork: _toggled(state.pastWork, code));

  static Set<String> _toggled(Set<String> set, String code) {
    final next = Set<String>.from(set);
    if (!next.remove(code)) next.add(code);
    return next;
  }

  void setFamilyWorkers(int n) =>
      state = state.copyWith(familyWorkers: n.clamp(0, 15));
  void setMoney(MoneyLevel? m) => state =
      m == null ? state.copyWith(clearMoney: true) : state.copyWith(money: m);

  // location
  void setSource(LocationSource s) =>
      state = state.copyWith(source: s, clearError: true);
  void setLat(String t) => state = state.copyWith(latText: t, clearError: true);
  void setLng(String t) => state = state.copyWith(lngText: t, clearError: true);

  /// The location the bundled SAMPLE data is built around (a village near Trimbak, Nashik).
  /// One tap fills it in as typed coordinates, so a demo needs no GPS and no typing.
  void useDefaultCoordinates() => state = state.copyWith(
        source: LocationSource.manual,
        latText: kDefaultLatText,
        lngText: kDefaultLngText,
        clearError: true,
      );

  void setGps(double lat, double lng, double? accuracy) =>
      state = state.copyWith(
        source: LocationSource.gps,
        latText: lat.toStringAsFixed(6),
        lngText: lng.toStringAsFixed(6),
        accuracyM: accuracy,
        clearError: true,
      );

  /// The problem on [step], as a string key, or null when it is fine. Every question is optional,
  /// so only malformed answers are problems.
  String? errorFor(int step) {
    switch (step) {
      case 0:
        if (state.areaText.trim().isNotEmpty) {
          final v = state.areaValue;
          if (v == null || v <= 0 || !v.isFinite) return 'lv_err_area';
        }
        return null;
      case 4:
        if (state.source == LocationSource.villageCentre) return null;
        final lat = IntakeState.parseNumber(state.latText);
        final lng = IntakeState.parseNumber(state.lngText);
        if (lat == null || lng == null) return 'lv_err_coords';
        if (!insideMaharashtra(lat, lng)) return 'lv_err_outside_mh';
        return null;
      default:
        return null;
    }
  }

  /// Move on if this step is fine. Returns whether it moved.
  bool next() {
    final error = errorFor(state.step);
    if (error != null) {
      state = state.copyWith(errorKey: error);
      return false;
    }
    if (!state.isLast) {
      state = state.copyWith(step: state.step + 1, clearError: true);
    }
    return true;
  }

  void back() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, clearError: true);
    }
  }

  /// True if the whole form is valid, so it can be saved.
  bool validateForSave() {
    for (final s in [0, 4]) {
      final error = errorFor(s);
      if (error != null) {
        state = state.copyWith(step: s, errorKey: error);
        return false;
      }
    }
    return true;
  }
}

/// A fresh form each time the screen opens, filled with what he saved before.
final intakeProvider =
    StateNotifierProvider.autoDispose<IntakeNotifier, IntakeState>(
  (ref) => IntakeNotifier(IntakeState.fromProfile(ref.read(profileProvider))),
);
