import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/contractor_marketplace_service.dart';
import 'package:makon3d_mobile/services/geocode_service.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/theme/makon_colors.dart';
import 'package:makon3d_mobile/widgets/keyboard_dismiss_scope.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Five-step customer flow that turns a Makon3D project into a contractor brief.
class ContractorListingFlowScreen extends StatefulWidget {
  const ContractorListingFlowScreen({required this.projectId, super.key});

  final String projectId;

  @override
  State<ContractorListingFlowScreen> createState() =>
      _ContractorListingFlowScreenState();
}

class _ContractorListingFlowScreenState
    extends State<ContractorListingFlowScreen> {
  static const _stepCount = 5;

  late final TextEditingController _locationController;
  late final TextEditingController _budgetMinController;
  late final TextEditingController _budgetMaxController;
  late final TextEditingController _commentController;

  int _step = 0;
  bool _isSaving = false;
  bool _locating = false;
  late Set<ContractorWorkType> _workTypes;
  late List<ContractorWorkVolume> _detectedVolumes;
  late bool _includeDetectedVolumes;
  late ContractorBudgetMode _budgetMode;
  late DateTime _startDate;
  late int _durationDays;
  late bool _siteVisitAvailable;
  late bool _show3dPreview;
  late bool _showFloorPlan;
  late bool _showMeasurements;
  late bool _showMaterialEstimate;
  late bool _showPhotos;
  late bool _showExactAddress;

  MakonProject? get _project =>
      MakonProjectStore.instance.getById(widget.projectId);

  ContractorListing? get _existingListing => _project?.contractorListing;

  bool get _isEditing => _existingListing != null;

  @override
  void initState() {
    super.initState();
    final project = _project;
    final listing = project?.contractorListing;
    _workTypes =
        listing?.workTypes.toSet() ??
        <ContractorWorkType>{ContractorWorkType.fullRenovation};
    _detectedVolumes = listing?.detectedVolumes.isNotEmpty == true
        ? listing!.detectedVolumes
        : _buildDetectedVolumes(project);
    _includeDetectedVolumes = listing?.detectedVolumes.isNotEmpty == true;
    _locationController = TextEditingController(
      text: listing?.publicLocation ?? '',
    );
    _budgetMinController = TextEditingController(
      text: _formatInputNumber(listing?.budgetMinMillion),
    );
    _budgetMaxController = TextEditingController(
      text: _formatInputNumber(listing?.budgetMaxMillion),
    );
    _commentController = TextEditingController(text: listing?.comment ?? '');
    _budgetMode = listing?.budgetMode ?? ContractorBudgetMode.openOffers;
    _startDate =
        listing?.startDate ??
        DateUtils.dateOnly(DateTime.now().add(const Duration(days: 7)));
    _durationDays = listing?.desiredDurationDays ?? 30;
    _siteVisitAvailable = listing?.siteVisitAvailable ?? false;
    final visibility =
        listing?.visibility ?? const ContractorListingVisibility();
    _show3dPreview = visibility.show3dPreview;
    _showFloorPlan = visibility.showFloorPlan;
    _showMeasurements = visibility.showMeasurements;
    _showMaterialEstimate = visibility.showMaterialEstimate;
    _showPhotos = visibility.showPhotos;
    // Exact address is never public. It can only be revealed to the accepted
    // contractor from the offers screen.
    _showExactAddress = false;
  }

  @override
  void dispose() {
    _locationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  static String _formatInputNumber(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  static List<ContractorWorkVolume> _buildDetectedVolumes(
    MakonProject? project,
  ) {
    if (project == null) return const <ContractorWorkVolume>[];
    final scans = <HousingScan>[
      ?project.entireHousingScan,
      for (final room in project.rooms) ?room.scan,
    ];
    if (scans.isEmpty) return const <ContractorWorkVolume>[];

    var floorArea = 0.0;
    var wallpaperArea = 0.0;
    var baseboardLength = 0.0;
    var doorCount = 0;
    for (final scan in scans) {
      floorArea += scan.floorAreaM2 ?? 0;
      final perimeter = scan.wallPerimeterM ?? 0;
      final openings = (scan.doorwayAreaM2 ?? 0) + (scan.windowAreaM2 ?? 0);
      wallpaperArea += ((perimeter * (scan.heightM ?? 0)) - openings).clamp(
        0,
        double.infinity,
      );
      baseboardLength += (perimeter - (scan.doorwayWidthM ?? 0)).clamp(
        0,
        double.infinity,
      );
      doorCount += scan.objectCounts['door'] ?? 0;
    }

    return <ContractorWorkVolume>[
      if (floorArea > 0)
        ContractorWorkVolume(
          type: ContractorWorkType.laminate,
          amount: floorArea,
          unit: ContractorVolumeUnit.squareMeters,
        ),
      if (wallpaperArea > 0)
        ContractorWorkVolume(
          type: ContractorWorkType.wallpaper,
          amount: wallpaperArea,
          unit: ContractorVolumeUnit.squareMeters,
        ),
      if (baseboardLength > 0)
        ContractorWorkVolume(
          type: ContractorWorkType.baseboard,
          amount: baseboardLength,
          unit: ContractorVolumeUnit.meters,
        ),
      if (doorCount > 0)
        ContractorWorkVolume(
          type: ContractorWorkType.doors,
          amount: doorCount.toDouble(),
          unit: ContractorVolumeUnit.pieces,
        ),
    ];
  }

  double? _parseBudget(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _workTypes.isNotEmpty;
      case 1:
        return _locationController.text.trim().isNotEmpty;
      case 2:
        if (_budgetMode != ContractorBudgetMode.range) return true;
        final min = _parseBudget(_budgetMinController.text);
        final max = _parseBudget(_budgetMaxController.text);
        return min != null && max != null && min > 0 && max >= min;
      case 3:
      case 4:
        return true;
    }
    return false;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_canContinue) {
      setState(() {});
      return;
    }
    if (_step < _stepCount - 1) setState(() => _step += 1);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _publish() async {
    if (_isSaving || !_canContinue) return;
    final project = _project;
    if (project == null) return;
    setState(() => _isSaving = true);
    final previous = project.contractorListing;
    final listing = ContractorListing(
      workTypes: _workTypes.toList(growable: false),
      publicLocation: _locationController.text.trim(),
      visibility: ContractorListingVisibility(
        show3dPreview: _show3dPreview,
        showFloorPlan: _showFloorPlan,
        showMeasurements: _showMeasurements,
        showMaterialEstimate: _showMaterialEstimate,
        showPhotos: _showPhotos,
        showExactAddress: _showExactAddress,
      ),
      budgetMode: _budgetMode,
      detectedVolumes: _includeDetectedVolumes
          ? _detectedVolumes
          : const <ContractorWorkVolume>[],
      budgetMinMillion: _budgetMode == ContractorBudgetMode.range
          ? _parseBudget(_budgetMinController.text)
          : null,
      budgetMaxMillion: _budgetMode == ContractorBudgetMode.range
          ? _parseBudget(_budgetMaxController.text)
          : null,
      startDate: _startDate,
      desiredDurationDays: _durationDays,
      siteVisitAvailable: _siteVisitAvailable,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      publishedAt: previous?.publishedAt ?? DateTime.now(),
      responseCount: previous?.responseCount ?? 0,
    );
    try {
      final job = await ContractorMarketplaceService.publishJob(
        project: project,
        listing: listing,
      );
      final confirmedListing = listing.copyWith(
        remoteJobId: job.id,
        responseCount: job.offerCount,
        status: job.status,
      );
      await MakonProjectStore.instance.upsert(
        project.copyWith(contractorListing: confirmedListing),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Toasts.showError(context, L10n.get('contractor_publish_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(L10n.get('project_not_found'))),
      );
    }
    final stepTitles = <String>[
      L10n.get('contractor_step_work'),
      L10n.get('contractor_step_access'),
      L10n.get('contractor_step_budget'),
      L10n.get('contractor_step_timing'),
      L10n.get('contractor_step_preview'),
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? L10n.get('contractor_edit_listing')
                    : L10n.get('contractor_publish_title'),
              ),
              Text(
                project.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _FlowProgress(
              step: _step,
              stepCount: _stepCount,
              label: stepTitles[_step],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _buildWorkStep(context),
                    1 => _buildAccessStep(context),
                    2 => _buildBudgetStep(context),
                    3 => _buildTimingStep(context),
                    _ => _buildPreviewStep(context, project),
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _FlowFooter(
          isFirstStep: _step == 0,
          isLastStep: _step == _stepCount - 1,
          isEnabled: _canContinue,
          isSaving: _isSaving,
          isEditing: _isEditing,
          onBack: _back,
          onNext: _step == _stepCount - 1 ? _publish : _next,
        ),
      ),
    );
  }

  Widget _stepScrollView(List<Widget> children) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: children,
    );
  }

  Widget _buildWorkStep(BuildContext context) {
    final selectableTypes = ContractorWorkType.values
        .where((type) => type != ContractorWorkType.baseboard)
        .toList(growable: false);
    return _stepScrollView([
      _SectionIntro(
        title: L10n.get('contractor_work_title'),
        subtitle: L10n.get('contractor_work_subtitle'),
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 9,
        runSpacing: 10,
        children: [
          for (final type in selectableTypes)
            FilterChip(
              selected: _workTypes.contains(type),
              avatar: Icon(type.icon, size: 19),
              label: Text(type.label),
              showCheckmark: false,
              selectedColor: MakonColors.yellowSoft,
              side: BorderSide(
                color: _workTypes.contains(type)
                    ? MakonColors.ink
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _workTypes.add(type);
                  } else {
                    _workTypes.remove(type);
                  }
                });
              },
            ),
        ],
      ),
      if (_workTypes.isEmpty) ...[
        const SizedBox(height: 10),
        Text(
          L10n.get('contractor_work_required'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 26),
      if (_detectedVolumes.isNotEmpty)
        _DetectedWorkCard(
          volumes: _detectedVolumes,
          isAdded: _includeDetectedVolumes,
          onToggle: () {
            setState(() {
              _includeDetectedVolumes = !_includeDetectedVolumes;
              if (_includeDetectedVolumes) {
                _workTypes.addAll(
                  _detectedVolumes.map((volume) => volume.type),
                );
              }
            });
          },
        )
      else
        _InfoCard(
          icon: Icons.auto_awesome_outlined,
          title: L10n.get('contractor_detected_empty_title'),
          subtitle: L10n.get('contractor_detected_empty_subtitle'),
        ),
    ]);
  }

  /// Fills the public location field from the device GPS — same flow as
  /// new/edit project address fields.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    KeyboardDismissScope.dismiss();
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        Toasts.showInfo(context, L10n.get('location_services_disabled'));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        Toasts.showInfo(context, L10n.get('location_permission_denied'));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final address = await GeocodeService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
        lang: LanguageState().currentLanguage,
      );
      if (!mounted) return;
      if (address == null) {
        Toasts.showError(context, L10n.get('current_location_address_failed'));
        return;
      }
      _locationController.text = address;
      setState(() {});
    } on TimeoutException {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('current_location_address_failed'));
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('current_location_address_failed'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _buildAccessStep(BuildContext context) {
    return _stepScrollView([
      _SectionIntro(
        title: L10n.get('contractor_access_title'),
        subtitle: L10n.get('contractor_access_subtitle'),
      ),
      const SizedBox(height: 22),
      TextField(
        controller: _locationController,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: L10n.get('contractor_public_location'),
          hintText: L10n.get('contractor_public_location_hint'),
          prefixIcon: const Icon(Icons.location_on_outlined),
          suffixIcon: _locating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: L10n.get('use_current_location'),
                  icon: const Icon(Icons.my_location),
                  onPressed: () => unawaited(_useCurrentLocation()),
                ),
          border: const OutlineInputBorder(),
          errorText: _locationController.text.trim().isEmpty
              ? L10n.get('contractor_public_location_required')
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      _InfoCard(
        icon: Icons.shield_outlined,
        title: L10n.get('contractor_address_protected_title'),
        subtitle: L10n.get('contractor_address_protected_subtitle'),
        highlighted: true,
      ),
      const SizedBox(height: 22),
      Text(
        L10n.get('contractor_share_heading'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      _VisibilityTile(
        icon: Icons.view_in_ar_outlined,
        title: L10n.get('contractor_share_3d'),
        value: _show3dPreview,
        onChanged: (value) => setState(() => _show3dPreview = value),
      ),
      _VisibilityTile(
        icon: Icons.map_outlined,
        title: L10n.get('contractor_share_plan'),
        value: _showFloorPlan,
        onChanged: (value) => setState(() => _showFloorPlan = value),
      ),
      _VisibilityTile(
        icon: Icons.straighten_outlined,
        title: L10n.get('contractor_share_measurements'),
        value: _showMeasurements,
        onChanged: (value) => setState(() => _showMeasurements = value),
      ),
      _VisibilityTile(
        icon: Icons.calculate_outlined,
        title: L10n.get('contractor_share_materials'),
        value: _showMaterialEstimate,
        onChanged: (value) => setState(() => _showMaterialEstimate = value),
      ),
      _VisibilityTile(
        icon: Icons.photo_library_outlined,
        title: L10n.get('contractor_share_photos'),
        value: _showPhotos,
        onChanged: (value) => setState(() => _showPhotos = value),
      ),
      _VisibilityTile(
        icon: Icons.pin_drop_outlined,
        title: L10n.get('contractor_share_address'),
        subtitle: L10n.get('contractor_share_address_warning'),
        value: false,
        isSensitive: true,
        onChanged: null,
      ),
    ]);
  }

  Widget _buildBudgetStep(BuildContext context) {
    return _stepScrollView([
      _SectionIntro(
        title: L10n.get('contractor_budget_title'),
        subtitle: L10n.get('contractor_budget_subtitle'),
      ),
      const SizedBox(height: 22),
      _BudgetModeCard(
        mode: ContractorBudgetMode.openOffers,
        currentMode: _budgetMode,
        icon: Icons.forum_outlined,
        title: L10n.get('contractor_budget_open_title'),
        subtitle: L10n.get('contractor_budget_open_subtitle'),
        badge: L10n.get('contractor_recommended'),
        onTap: () =>
            setState(() => _budgetMode = ContractorBudgetMode.openOffers),
      ),
      _BudgetModeCard(
        mode: ContractorBudgetMode.range,
        currentMode: _budgetMode,
        icon: Icons.payments_outlined,
        title: L10n.get('contractor_budget_range_title'),
        subtitle: L10n.get('contractor_budget_range_subtitle'),
        onTap: () => setState(() => _budgetMode = ContractorBudgetMode.range),
      ),
      _BudgetModeCard(
        mode: ContractorBudgetMode.competition,
        currentMode: _budgetMode,
        icon: Icons.workspace_premium_outlined,
        title: L10n.get('contractor_budget_competition_title'),
        subtitle: L10n.get('contractor_budget_competition_subtitle'),
        onTap: () =>
            setState(() => _budgetMode = ContractorBudgetMode.competition),
      ),
      if (_budgetMode == ContractorBudgetMode.range) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _budgetMinController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: L10n.get('contractor_budget_min'),
                  suffixText: L10n.get('contractor_budget_unit'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _budgetMaxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: L10n.get('contractor_budget_max'),
                  suffixText: L10n.get('contractor_budget_unit'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
      if (_budgetMode == ContractorBudgetMode.competition) ...[
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.auto_awesome_outlined,
          title: L10n.get('contractor_competition_note_title'),
          subtitle: L10n.get('contractor_competition_note_subtitle'),
          highlighted: true,
        ),
      ],
    ]);
  }

  Widget _buildTimingStep(BuildContext context) {
    final formattedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(_startDate);
    return _stepScrollView([
      _SectionIntro(
        title: L10n.get('contractor_timing_title'),
        subtitle: L10n.get('contractor_timing_subtitle'),
      ),
      const SizedBox(height: 22),
      ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text(L10n.get('contractor_start_date')),
        subtitle: Text(formattedDate),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: _startDate,
            firstDate: DateUtils.dateOnly(DateTime.now()),
            lastDate: DateTime.now().add(const Duration(days: 730)),
          );
          if (selected != null) setState(() => _startDate = selected);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: _durationDays,
        decoration: InputDecoration(
          labelText: L10n.get('contractor_duration'),
          prefixIcon: const Icon(Icons.schedule_outlined),
          border: const OutlineInputBorder(),
        ),
        items: [30, 45, 60]
            .map(
              (days) => DropdownMenuItem<int>(
                value: days,
                child: Text(
                  L10n.get(
                    'contractor_duration_days',
                  ).replaceAll('{count}', '$days'),
                ),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _durationDays = value ?? 30),
      ),
      const SizedBox(height: 18),
      _VisibilityTile(
        icon: Icons.location_searching_outlined,
        title: L10n.get('contractor_visit_title'),
        subtitle: L10n.get('contractor_visit_subtitle'),
        value: _siteVisitAvailable,
        onChanged: (value) => setState(() => _siteVisitAvailable = value),
      ),
      const SizedBox(height: 22),
      TextField(
        controller: _commentController,
        minLines: 4,
        maxLines: 6,
        maxLength: 280,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: L10n.get('contractor_comment'),
          hintText: L10n.get('contractor_comment_hint'),
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
      ),
    ]);
  }

  Widget _buildPreviewStep(BuildContext context, MakonProject project) {
    return _stepScrollView([
      _SectionIntro(
        title: L10n.get('contractor_preview_title'),
        subtitle: L10n.get('contractor_preview_subtitle'),
      ),
      const SizedBox(height: 22),
      _ContractorListingPreview(
        project: project,
        workTypes: _workTypes.toList(growable: false),
        detectedVolumes: _includeDetectedVolumes
            ? _detectedVolumes
            : const <ContractorWorkVolume>[],
        publicLocation: _locationController.text.trim(),
        budgetMode: _budgetMode,
        budgetMin: _parseBudget(_budgetMinController.text),
        budgetMax: _parseBudget(_budgetMaxController.text),
        startDate: _startDate,
        durationDays: _durationDays,
      ),
      const SizedBox(height: 16),
      _InfoCard(
        icon: Icons.lock_outline,
        title: L10n.get('contractor_privacy_ready_title'),
        subtitle: L10n.get('contractor_privacy_hidden_address'),
        highlighted: true,
      ),
    ]);
  }
}

class _FlowProgress extends StatelessWidget {
  const _FlowProgress({
    required this.step,
    required this.stepCount,
    required this.label,
  });

  final int step;
  final int stepCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L10n.get('contractor_step_of')
                      .replaceAll('{current}', '${step + 1}')
                      .replaceAll('{total}', '$stepCount'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (step + 1) / stepCount,
              color: MakonColors.yellow,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowFooter extends StatelessWidget {
  const _FlowFooter({
    required this.isFirstStep,
    required this.isLastStep,
    required this.isEnabled,
    required this.isSaving,
    required this.isEditing,
    required this.onBack,
    required this.onNext,
  });

  final bool isFirstStep;
  final bool isLastStep;
  final bool isEnabled;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            if (!isFirstStep) ...[
              OutlinedButton(
                onPressed: isSaving ? null : onBack,
                child: Text(L10n.get('back')),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: isEnabled && !isSaving ? onNext : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isLastStep
                            ? (isEditing
                                  ? L10n.get('contractor_save_listing')
                                  : L10n.get('contractor_publish'))
                            : L10n.get('contractor_continue'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted
            ? MakonColors.yellowSoft
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MakonColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedWorkCard extends StatelessWidget {
  const _DetectedWorkCard({
    required this.volumes,
    required this.isAdded,
    required this.onToggle,
  });

  final List<ContractorWorkVolume> volumes;
  final bool isAdded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: MakonColors.yellowSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAdded ? MakonColors.ink : MakonColors.yellow,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: MakonColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.get('contractor_detected_title'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(L10n.get('contractor_detected_subtitle')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final volume in volumes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(volume.type.label)),
                  Text(
                    volume.formattedAmount,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: MakonColors.ink,
                side: const BorderSide(color: MakonColors.ink),
              ),
              onPressed: onToggle,
              icon: Icon(isAdded ? Icons.check : Icons.add),
              label: Text(
                L10n.get(
                  isAdded
                      ? 'contractor_detected_added'
                      : 'contractor_add_detected',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.isSensitive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isSensitive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: isSensitive && value
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          secondary: Icon(icon),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BudgetModeCard extends StatelessWidget {
  const _BudgetModeCard({
    required this.mode,
    required this.currentMode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final ContractorBudgetMode mode;
  final ContractorBudgetMode currentMode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = mode == currentMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? MakonColors.yellowSoft
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? MakonColors.ink
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? MakonColors.ink
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            color: MakonColors.ink,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 2),
                Icon(icon, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MakonColors.yellow,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractorListingPreview extends StatelessWidget {
  const _ContractorListingPreview({
    required this.project,
    required this.workTypes,
    required this.detectedVolumes,
    required this.publicLocation,
    required this.budgetMode,
    required this.budgetMin,
    required this.budgetMax,
    required this.startDate,
    required this.durationDays,
  });

  final MakonProject project;
  final List<ContractorWorkType> workTypes;
  final List<ContractorWorkVolume> detectedVolumes;
  final String publicLocation;
  final ContractorBudgetMode budgetMode;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime startDate;
  final int durationDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final area = _projectArea(project);
    final date = MaterialLocalizations.of(context).formatMediumDate(startDate);
    final volumeByType = {
      for (final volume in detectedVolumes) volume.type: volume,
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: MakonColors.ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: MakonColors.yellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    L10n.get('contractor_preview_new_order'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: MakonColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  L10n.get('contractor_preview_order_title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: MakonColors.onDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  [
                    publicLocation,
                    if (area > 0) '${_formatAmount(area)} m²',
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MakonColors.onDark.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get('contractor_preview_work_heading'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                for (final type in workTypes.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(type.label)),
                        if (volumeByType[type] case final volume?)
                          Text(
                            volume.formattedAmount,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                  ),
                const Divider(height: 30),
                _PreviewMetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: L10n.get('contractor_start_date'),
                  value: date,
                ),
                _PreviewMetaRow(
                  icon: Icons.schedule_outlined,
                  label: L10n.get('contractor_duration'),
                  value: L10n.get(
                    'contractor_duration_days',
                  ).replaceAll('{count}', '$durationDays'),
                ),
                _PreviewMetaRow(
                  icon: Icons.payments_outlined,
                  label: L10n.get('contractor_preview_budget'),
                  value: _budgetText(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _budgetText() {
    return switch (budgetMode) {
      ContractorBudgetMode.openOffers => L10n.get(
        'contractor_budget_open_value',
      ),
      ContractorBudgetMode.competition => L10n.get(
        'contractor_budget_competition_title',
      ),
      ContractorBudgetMode.range =>
        '${_formatAmount(budgetMin ?? 0)}–${_formatAmount(budgetMax ?? 0)} ${L10n.get('contractor_budget_unit')}',
    };
  }

  static double _projectArea(MakonProject project) {
    final entireArea = project.entireHousingScan?.floorAreaM2;
    if (entireArea != null && entireArea > 0) return entireArea;
    return project.rooms.fold<double>(
      0,
      (sum, room) => sum + (room.scan?.floorAreaM2 ?? 0),
    );
  }
}

class _PreviewMetaRow extends StatelessWidget {
  const _PreviewMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

extension on ContractorWorkType {
  String get label => L10n.get(switch (this) {
    ContractorWorkType.fullRenovation => 'contractor_work_full',
    ContractorWorkType.laminate => 'contractor_work_laminate',
    ContractorWorkType.wallpaper => 'contractor_work_wallpaper',
    ContractorWorkType.tile => 'contractor_work_tile',
    ContractorWorkType.painting => 'contractor_work_painting',
    ContractorWorkType.electrical => 'contractor_work_electrical',
    ContractorWorkType.plumbing => 'contractor_work_plumbing',
    ContractorWorkType.doors => 'contractor_work_doors',
    ContractorWorkType.baseboard => 'contractor_work_baseboard',
    ContractorWorkType.other => 'contractor_work_other',
  });

  IconData get icon => switch (this) {
    ContractorWorkType.fullRenovation => Icons.home_repair_service_outlined,
    ContractorWorkType.laminate => Icons.grid_on_outlined,
    ContractorWorkType.wallpaper => Icons.texture_outlined,
    ContractorWorkType.tile => Icons.window_outlined,
    ContractorWorkType.painting => Icons.format_paint_outlined,
    ContractorWorkType.electrical => Icons.electrical_services_outlined,
    ContractorWorkType.plumbing => Icons.plumbing_outlined,
    ContractorWorkType.doors => Icons.door_front_door_outlined,
    ContractorWorkType.baseboard => Icons.linear_scale_outlined,
    ContractorWorkType.other => Icons.more_horiz,
  };
}

extension on ContractorWorkVolume {
  String get formattedAmount {
    final amountText = _formatAmount(amount);
    final unitText = switch (unit) {
      ContractorVolumeUnit.squareMeters => 'm²',
      ContractorVolumeUnit.meters => 'm',
      ContractorVolumeUnit.pieces => L10n.get('contractor_unit_pieces'),
    };
    return '$amountText $unitText';
  }
}

String _formatAmount(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
