import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/error_mapping.dart';
import '../data/location_service.dart';
import '../livelihood_strings.dart';
import '../models/profile.dart';
import '../providers/intake_provider.dart';
import '../providers/livelihood_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/intake_widgets.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/report_parts.dart';

/// "Add your details": five short steps. Every question is optional (PDF §10); only a number that
/// does not make sense is refused. Answers are saved on the phone and shown back as "Told by you".
class AddDetailsScreen extends ConsumerWidget {
  const AddDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final state = ref.watch(intakeProvider);
    final notifier = ref.read(intakeProvider.notifier);

    final titles = [
      s.t('lv_step_land'),
      s.t('lv_step_animals'),
      s.t('lv_step_own'),
      s.t('lv_step_work'),
      s.t('lv_step_location'),
    ];

    return PopScope(
      canPop: state.step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          notifier.back(); // the phone's back button goes to the previous step
        }
      },
      child: LvScaffold(
        title: s.t('lv_add_details'),
        body: Column(
          children: [
            _StepHeader(step: state.step, title: titles[state.step]),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                children: [
                  switch (state.step) {
                    0 => _LandStep(state: state, notifier: notifier),
                    1 => _AnimalsStep(state: state, notifier: notifier),
                    2 => _OwnStep(state: state, notifier: notifier),
                    3 => _WorkStep(state: state, notifier: notifier),
                    _ => _LocationStep(state: state, notifier: notifier),
                  },
                  NoteLine(
                    s.t('lv_optional_note'),
                    icon: Icons.lock_outline_rounded,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.cardBg,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  if (state.step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: notifier.back,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(
                          s.t('lv_back'),
                          style: AppTypography.labelLarge.copyWith(
                            color: c.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          _onPrimary(context, ref, state, notifier),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.saffron,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        s.t(state.isLast ? 'lv_save_details' : 'lv_next'),
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPrimary(
    BuildContext context,
    WidgetRef ref,
    IntakeState state,
    IntakeNotifier notifier,
  ) async {
    if (!state.isLast) {
      notifier.next();
      return;
    }
    if (!notifier.validateForSave()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final s = LivelihoodStrings.of(context);
    try {
      await ref
          .read(profileProvider.notifier)
          .save(ref.read(intakeProvider).toProfile());
      ref.invalidate(
        reportProvider,
      ); // his next look builds a report from the new details
      navigator.pop();
    } catch (e) {
      // a plain-language reason (not signed in, outside Maharashtra...), never a raw code
      final key = errorMessageKey(e);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            key == 'lv_err_generic' ? s.t('lv_save_failed') : s.t(key),
          ),
        ),
      );
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title});

  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: s.t('lv_step_of', {'n': step + 1, 'total': kIntakeSteps}),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (step + 1) / kIntakeSteps,
                minHeight: 6,
                color: AppColors.saffron,
                backgroundColor: c.border,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.t('lv_step_of', {'n': step + 1, 'total': kIntakeSteps}),
            style: AppTypography.caption.copyWith(color: c.textSecondary),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.display.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.errorKey);

  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    if (errorKey == null) return const SizedBox.shrink();
    final s = LivelihoodStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppColors.alertRed,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              s.t(errorKey!),
              style: AppTypography.body.copyWith(
                color: context.colors.isDark
                    ? const Color(0xFFFF8A80)
                    : AppColors.alertRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandStep extends StatelessWidget {
  const _LandStep({required this.state, required this.notifier});

  final IntakeState state;
  final IntakeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final units = {
      AreaUnit.acre: s.t('lv_unit_acre'),
      AreaUnit.guntha: s.t('lv_unit_guntha'),
      AreaUnit.hectare: s.t('lv_unit_hectare'),
    };
    final ha = state.areaHa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(s.t('lv_land_area')),
        TextFormField(
          key: const ValueKey('area_field'),
          initialValue: state.areaText,
          onChanged: notifier.setArea,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: AppTypography.titleMedium.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            labelText: s.t('lv_area_hint'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AreaUnit>(
            segments: [
              for (final e in units.entries)
                ButtonSegment(
                  value: e.key,
                  label: Text(e.value),
                  tooltip: e.value,
                ),
            ],
            selected: {state.unit},
            showSelectedIcon: true,
            onSelectionChanged: (set) => notifier.setUnit(set.first),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(48, 52)),
            ),
          ),
        ),
        if (ha != null && state.unit != AreaUnit.hectare)
          NoteLine(
            s.t('lv_area_converted', {'ha': ha.toStringAsFixed(2)}),
            icon: Icons.swap_horiz_rounded,
          ),
        if (state.areaLooksTooBig)
          NoteLine(s.t('lv_area_check'), icon: Icons.warning_amber_rounded),
        _ErrorLine(state.errorKey),
        FieldLabel(s.t('lv_land_type')),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in LandType.values)
              ChoicePill(
                label: s.t('lv_type_${t.wire}'),
                selected: state.landType == t,
                onTap: () =>
                    notifier.setLandType(state.landType == t ? null : t),
              ),
          ],
        ),
        FieldLabel(s.t('lv_water_on_land')),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final w in WaterOnLand.values)
              ChoicePill(
                label: s.t('lv_water_${w.wire}'),
                selected: state.water == w,
                onTap: () => notifier.setWater(state.water == w ? null : w),
              ),
          ],
        ),
      ],
    );
  }
}

class _AnimalsStep extends StatelessWidget {
  const _AnimalsStep({required this.state, required this.notifier});

  final IntakeState state;
  final IntakeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('lv_animals_hint'),
          style: AppTypography.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final code in kAnimalCodes)
          CounterTile(
            icon: iconForCode(code),
            label: s.animal(code),
            count: state.animals[code] ?? 0,
            onChanged: (n) => notifier.setAnimal(code, n),
          ),
      ],
    );
  }
}

class _OwnStep extends StatelessWidget {
  const _OwnStep({required this.state, required this.notifier});

  final IntakeState state;
  final IntakeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('lv_own_hint'),
          style: AppTypography.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final code in kAssetCodes)
          ChoiceTile(
            icon: iconForCode(code),
            label: s.asset(code),
            selected: state.assets.contains(code),
            onTap: () => notifier.toggleAsset(code),
          ),
      ],
    );
  }
}

class _WorkStep extends StatelessWidget {
  const _WorkStep({required this.state, required this.notifier});

  final IntakeState state;
  final IntakeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final workers = state.familyWorkers ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('lv_work_title'),
          style: AppTypography.subtitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final code in kPastWorkCodes)
          ChoiceTile(
            label: s.t('w_$code'),
            selected: state.pastWork.contains(code),
            onTap: () => notifier.togglePastWork(code),
          ),
        FieldLabel(s.t('lv_family_workers')),
        CounterTile(
          icon: Icons.groups_rounded,
          label: s.t('lv_family_workers'),
          count: workers,
          max: 15,
          onChanged: notifier.setFamilyWorkers,
        ),
        FieldLabel(s.t('lv_money')),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final m in MoneyLevel.values)
              ChoicePill(
                label: s.t('lv_money_${m.wire}'),
                selected: state.money == m,
                onTap: () => notifier.setMoney(state.money == m ? null : m),
              ),
          ],
        ),
      ],
    );
  }
}

class _LocationStep extends ConsumerStatefulWidget {
  const _LocationStep({required this.state, required this.notifier});

  final IntakeState state;
  final IntakeNotifier notifier;

  @override
  ConsumerState<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<_LocationStep> {
  bool _finding = false;
  String? _failureKey;

  Future<void> _useGps() async {
    setState(() {
      _finding = true;
      _failureKey = null;
    });
    try {
      final fix = await ref.read(locationServiceProvider).currentFix();
      widget.notifier.setGps(fix.lat, fix.lng, fix.accuracyM);
    } on LocationException catch (e) {
      _failureKey = switch (e.failure) {
        LocationFailure.servicesOff => 'lv_loc_off',
        LocationFailure.denied => 'lv_loc_denied',
        LocationFailure.deniedForever => 'lv_loc_denied_forever',
        LocationFailure.failed => 'lv_loc_failed',
      };
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final state = widget.state;
    final notifier = widget.notifier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        _SourceCard(
          icon: Icons.my_location_rounded,
          label: s.t('lv_loc_gps'),
          selected: state.source == LocationSource.gps,
          onTap: _finding ? null : _useGps,
          child: _finding
              ? Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.saffron,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      s.t('lv_loc_getting'),
                      style: AppTypography.body.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                )
              : state.source == LocationSource.gps && state.latText.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('lv_loc_got', {
                            'lat': state.latText,
                            'lng': state.lngText,
                          }),
                          style:
                              AppTypography.body.copyWith(color: c.textPrimary),
                        ),
                        if (state.accuracyM != null)
                          Text(
                            s.t('lv_loc_accuracy', {
                              'acc': state.accuracyM!.round(),
                            }),
                            style: AppTypography.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    )
                  : null,
        ),
        if (_failureKey != null) _ErrorLine(_failureKey),
        _SourceCard(
          icon: Icons.edit_location_alt_outlined,
          label: s.t('lv_loc_manual'),
          selected: state.source == LocationSource.manual,
          onTap: () => notifier.setSource(LocationSource.manual),
          child: state.source == LocationSource.manual
              ? Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _CoordField(
                      key: const ValueKey('lat_field'),
                      label: s.t('lv_lat'),
                      value: state.latText,
                      onChanged: notifier.setLat,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CoordField(
                      key: const ValueKey('lng_field'),
                      label: s.t('lv_lng'),
                      value: state.lngText,
                      onChanged: notifier.setLng,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const ValueKey('default_coords'),
                      onPressed: notifier.useDefaultCoordinates,
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: Text(s.t('lv_loc_default')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.border),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        s.t('lv_loc_default_note'),
                        style: AppTypography.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
        _SourceCard(
          icon: Icons.home_work_outlined,
          label: s.t('lv_loc_village'),
          selected: state.source == LocationSource.villageCentre,
          onTap: () => notifier.setSource(LocationSource.villageCentre),
          child: state.source == LocationSource.villageCentre
              ? Text(
                  s.t('lv_loc_village_note'),
                  style: AppTypography.body.copyWith(color: c.textSecondary),
                )
              : null,
        ),
        _ErrorLine(state.errorKey),
      ],
    );
  }
}

class _CoordField extends StatefulWidget {
  const _CoordField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CoordField> createState() => _CoordFieldState();
}

class _CoordFieldState extends State<_CoordField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_CoordField old) {
    super.didUpdateWidget(old);
    // the value was changed from outside ("Use default coordinates"), not by typing
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      style: AppTypography.bodyLarge.copyWith(
        color: context.colors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

/// A selectable card for one way of fixing his location, with room for detail inside.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.child,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: selected
              ? AppColors.forestSage.withValues(alpha: 0.12)
              : c.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: selected ? AppColors.forestSage : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Row(
                      children: [
                        Icon(icon, color: c.textSecondary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            label,
                            style: AppTypography.titleMedium.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color:
                              selected ? AppColors.forestSage : c.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  if (child != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    child!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
