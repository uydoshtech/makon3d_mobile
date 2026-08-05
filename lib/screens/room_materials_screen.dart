import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/floor_tile_prefs.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/models/wallpaper_prefs.dart';
import 'package:makon3d_mobile/screens/floor_tile_layout_screen.dart';
import 'package:makon3d_mobile/services/floor_tile_estimate.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/keyboard_dismiss_scope.dart';

/// Surface whose materials are being estimated.
enum MaterialsSurface { floor, walls }

/// Per-room (or entire-housing) material estimate:
/// floor → tiles + plinth, walls → wallpaper rolls.
class RoomMaterialsScreen extends StatefulWidget {
  const RoomMaterialsScreen({
    required this.projectId,
    this.roomId,
    this.initialSurface = MaterialsSurface.floor,
    this.showSurfaceSelector = true,
    super.key,
  });

  final String projectId;

  /// Null = entire-housing project (one measured space).
  final String? roomId;

  final MaterialsSurface initialSurface;

  /// Room details opens one material type directly; project-wide estimates
  /// retain the selector because they can cover both surfaces.
  final bool showSurfaceSelector;

  @override
  State<RoomMaterialsScreen> createState() => _RoomMaterialsScreenState();
}

class _TilePreset {
  const _TilePreset(this.widthCm, this.heightCm);
  final double widthCm;
  final double heightCm;

  bool matches(double w, double h) =>
      (w - widthCm).abs() < 0.001 && (h - heightCm).abs() < 0.001;
}

class _RollPreset {
  const _RollPreset(this.widthM, this.lengthM);
  final double widthM;
  final double lengthM;

  bool matches(double w, double l) =>
      (w - widthM).abs() < 0.001 && (l - lengthM).abs() < 0.001;
}

class _RoomMaterialsScreenState extends State<RoomMaterialsScreen> {
  static const _squarePresets = <_TilePreset>[
    _TilePreset(30, 30),
    _TilePreset(40, 40),
    _TilePreset(60, 60),
  ];
  static const _rectPresets = <_TilePreset>[
    _TilePreset(20, 30),
    _TilePreset(30, 60),
    _TilePreset(40, 50),
  ];

  /// Standard + wide European wallpaper rolls.
  static const _rollPresets = <_RollPreset>[
    _RollPreset(0.53, 10.05),
    _RollPreset(1.06, 10.05),
  ];

  late MaterialsSurface _surface;

  // Floor (tile) state.
  late bool _isSquare;
  late double _widthCm;
  late double _heightCm;
  late double _wastePercent;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;

  // Walls (wallpaper) state.
  late double _rollWidthM;
  late double _rollLengthM;
  late double _repeatCm;
  late final TextEditingController _rollWidthController;
  late final TextEditingController _rollLengthController;
  late final TextEditingController _repeatController;

  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _surface = widget.initialSurface;
    final tilePrefs = _loadFloorPrefs();
    _isSquare = tilePrefs.isSquare;
    _widthCm = tilePrefs.widthCm;
    _heightCm = tilePrefs.heightCm;
    _wastePercent = tilePrefs.wastePercent;
    _widthController = TextEditingController(text: _formatNumber(_widthCm));
    _heightController = TextEditingController(text: _formatNumber(_heightCm));

    final wallpaperPrefs = _loadWallpaperPrefs();
    _rollWidthM = wallpaperPrefs.rollWidthM;
    _rollLengthM = wallpaperPrefs.rollLengthM;
    _repeatCm = wallpaperPrefs.repeatCm;
    _rollWidthController = TextEditingController(
      text: _formatNumber(_rollWidthM),
    );
    _rollLengthController = TextEditingController(
      text: _formatNumber(_rollLengthM),
    );
    _repeatController = TextEditingController(text: _formatNumber(_repeatCm));

    MakonProjectStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    MakonProjectStore.instance.removeListener(_onStoreChanged);
    _widthController.dispose();
    _heightController.dispose();
    _rollWidthController.dispose();
    _rollLengthController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  MakonProject? get _project =>
      MakonProjectStore.instance.getById(widget.projectId);

  ProjectRoom? get _room {
    final id = widget.roomId;
    if (id == null) return null;
    final rooms = _project?.rooms;
    if (rooms == null) return null;
    for (final room in rooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  HousingScan? get _scan =>
      widget.roomId != null ? _room?.scan : _project?.entireHousingScan;

  bool get _walls => _surface == MaterialsSurface.walls;

  FloorTilePrefs _loadFloorPrefs() {
    if (widget.roomId != null) {
      return _room?.floorTilePrefs ?? FloorTilePrefs.defaults;
    }
    return _project?.entireHousingFloorTilePrefs ?? FloorTilePrefs.defaults;
  }

  WallpaperPrefs _loadWallpaperPrefs() {
    if (widget.roomId != null) {
      return _room?.wallpaperPrefs ?? WallpaperPrefs.defaults;
    }
    return _project?.entireHousingWallpaperPrefs ?? WallpaperPrefs.defaults;
  }

  String get _title {
    final room = _room;
    if (room != null) {
      if (room.name?.isNotEmpty == true) return room.name!;
      return L10n.get(room.roomType.titleKey);
    }
    return _project?.name ?? L10n.get('project_action_materials');
  }

  /// Up to 2 decimals, trailing zeros stripped ("40", "0.53", "10.05").
  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }

  double? _parseInput(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  void _setSurface(MaterialsSurface surface) {
    if (surface == _surface) return;
    KeyboardDismissScope.dismiss();
    // Flush pending edits for the surface we are leaving.
    _persistDebounce?.cancel();
    unawaited(_persistPrefs(_surface));
    setState(() => _surface = surface);
  }

  // --- Floor (tile) handlers -------------------------------------------------

  void _applyTilePreset(_TilePreset preset) {
    KeyboardDismissScope.dismiss();
    setState(() {
      _widthCm = preset.widthCm;
      _heightCm = preset.heightCm;
      _isSquare = preset.widthCm == preset.heightCm;
      _widthController.text = _formatNumber(_widthCm);
      _heightController.text = _formatNumber(_heightCm);
    });
    _schedulePersist();
  }

  void _setSquare(bool square) {
    KeyboardDismissScope.dismiss();
    setState(() {
      _isSquare = square;
      if (square) {
        _heightCm = _widthCm;
        _heightController.text = _formatNumber(_heightCm);
      }
    });
    _schedulePersist();
  }

  void _onWidthChanged(String raw) {
    final parsed = _parseInput(raw);
    if (parsed == null) return;
    setState(() {
      _widthCm = parsed;
      if (_isSquare) {
        _heightCm = parsed;
        _heightController.text = _formatNumber(parsed);
      }
    });
    _schedulePersist();
  }

  void _onHeightChanged(String raw) {
    final parsed = _parseInput(raw);
    if (parsed == null) return;
    setState(() {
      _heightCm = parsed;
      _isSquare = false;
    });
    _schedulePersist();
  }

  void _setWaste(double value) {
    KeyboardDismissScope.dismiss();
    setState(() => _wastePercent = value);
    _schedulePersist();
  }

  void _openTileLayout(FloorTileEstimate estimate) {
    KeyboardDismissScope.dismiss();
    final scan = _scan;
    final measuredLong = scan?.floorLongM;
    final measuredShort = scan?.floorShortM;

    double roomLengthM;
    double roomWidthM;
    if (measuredLong != null &&
        measuredLong > 0 &&
        measuredShort != null &&
        measuredShort > 0) {
      roomLengthM = measuredLong;
      roomWidthM = measuredShort;
    } else if (measuredLong != null && measuredLong > 0) {
      roomLengthM = measuredLong;
      roomWidthM = estimate.floorAreaM2 / measuredLong;
    } else if (measuredShort != null && measuredShort > 0) {
      roomWidthM = measuredShort;
      roomLengthM = estimate.floorAreaM2 / measuredShort;
    } else {
      roomLengthM = math.sqrt(estimate.floorAreaM2);
      roomWidthM = roomLengthM;
    }

    // Preserve the scanned room proportions while matching the measured floor
    // area. The stored length/width are bounding dimensions and can otherwise
    // overstate an irregular room's tile positions considerably.
    final boundsAreaM2 = roomLengthM * roomWidthM;
    if (boundsAreaM2 > 0) {
      final areaScale = math.sqrt(estimate.floorAreaM2 / boundsAreaM2);
      roomLengthM *= areaScale;
      roomWidthM *= areaScale;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FloorTileLayoutScreen(
          roomName: _title,
          roomWidthM: roomWidthM,
          roomLengthM: roomLengthM,
          tileWidthCm: _widthCm,
          tileLengthCm: _heightCm,
          purchaseTileCount: estimate.tileCount,
        ),
      ),
    );
  }

  // --- Walls (wallpaper) handlers --------------------------------------------

  void _applyRollPreset(_RollPreset preset) {
    KeyboardDismissScope.dismiss();
    setState(() {
      _rollWidthM = preset.widthM;
      _rollLengthM = preset.lengthM;
      _rollWidthController.text = _formatNumber(_rollWidthM);
      _rollLengthController.text = _formatNumber(_rollLengthM);
    });
    _schedulePersist();
  }

  void _onRollWidthChanged(String raw) {
    final parsed = _parseInput(raw);
    if (parsed == null) return;
    setState(() => _rollWidthM = parsed);
    _schedulePersist();
  }

  void _onRollLengthChanged(String raw) {
    final parsed = _parseInput(raw);
    if (parsed == null) return;
    setState(() => _rollLengthM = parsed);
    _schedulePersist();
  }

  void _onRepeatChanged(String raw) {
    // Repeat may legitimately be 0 — treat any non-negative parse as valid.
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return;
    setState(() => _repeatCm = parsed);
    _schedulePersist();
  }

  // --- Persistence -----------------------------------------------------------

  void _schedulePersist() {
    final surface = _surface;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistPrefs(surface));
    });
  }

  Future<void> _persistPrefs(MaterialsSurface surface) async {
    final project = _project;
    if (project == null) return;
    if (surface == MaterialsSurface.walls) {
      final prefs = WallpaperPrefs(
        rollWidthM: _rollWidthM,
        rollLengthM: _rollLengthM,
        repeatCm: _repeatCm,
      );
      if (widget.roomId != null) {
        final rooms = project.rooms
            .map((room) {
              if (room.id != widget.roomId) return room;
              return room.copyWith(wallpaperPrefs: prefs);
            })
            .toList(growable: false);
        await MakonProjectStore.instance.upsert(project.copyWith(rooms: rooms));
        return;
      }
      await MakonProjectStore.instance.upsert(
        project.copyWith(entireHousingWallpaperPrefs: prefs),
      );
      return;
    }
    final prefs = FloorTilePrefs(
      widthCm: _widthCm,
      heightCm: _heightCm,
      wastePercent: _wastePercent,
    );
    if (widget.roomId != null) {
      final rooms = project.rooms
          .map((room) {
            if (room.id != widget.roomId) return room;
            return room.copyWith(floorTilePrefs: prefs);
          })
          .toList(growable: false);
      await MakonProjectStore.instance.upsert(project.copyWith(rooms: rooms));
      return;
    }
    await MakonProjectStore.instance.upsert(
      project.copyWith(entireHousingFloorTilePrefs: prefs),
    );
  }

  // --- UI ---------------------------------------------------------------------

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      onChanged: onChanged,
    );
  }

  List<Widget> _buildFloorControls(ThemeData theme) {
    final presets = _isSquare ? _squarePresets : _rectPresets;
    return [
      Text(L10n.get('materials_tile_shape'), style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment<bool>(
            value: true,
            label: Text(L10n.get('materials_tile_square')),
          ),
          ButtonSegment<bool>(
            value: false,
            label: Text(L10n.get('materials_tile_rect')),
          ),
        ],
        selected: {_isSquare},
        onSelectionChanged: (next) {
          if (next.isEmpty) return;
          _setSquare(next.first);
        },
      ),
      const SizedBox(height: 20),
      Text(
        L10n.get('materials_tile_size_cm'),
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in presets)
            ChoiceChip(
              label: Text(
                '${_formatNumber(preset.widthCm)}×${_formatNumber(preset.heightCm)}',
              ),
              selected: preset.matches(_widthCm, _heightCm),
              onSelected: (_) => _applyTilePreset(preset),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _numberField(
              controller: _widthController,
              label: L10n.get('materials_tile_width_cm'),
              suffix: 'cm',
              onChanged: _onWidthChanged,
            ),
          ),
          if (!_isSquare) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
                controller: _heightController,
                label: L10n.get('materials_tile_height_cm'),
                suffix: 'cm',
                onChanged: _onHeightChanged,
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 24),
      Text(
        L10n.get(
          'materials_waste_label',
        ).replaceAll('{percent}', _wastePercent.round().toString()),
        style: theme.textTheme.titleSmall,
      ),
      Slider(
        value: _wastePercent.clamp(0, 20),
        min: 0,
        max: 20,
        divisions: 20,
        label: '${_wastePercent.round()}%',
        onChanged: _setWaste,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final step in const [5.0, 10.0, 15.0])
            TextButton(
              onPressed: () => _setWaste(step),
              child: Text('${step.round()}%'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildWallpaperControls(ThemeData theme) {
    return [
      Text(
        L10n.get('materials_roll_size_m'),
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in _rollPresets)
            ChoiceChip(
              label: Text(
                '${_formatNumber(preset.widthM)} × ${_formatNumber(preset.lengthM)}',
              ),
              selected: preset.matches(_rollWidthM, _rollLengthM),
              onSelected: (_) => _applyRollPreset(preset),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _numberField(
              controller: _rollWidthController,
              label: L10n.get('materials_tile_width_cm'),
              suffix: 'm',
              onChanged: _onRollWidthChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _numberField(
              controller: _rollLengthController,
              label: L10n.get('materials_tile_height_cm'),
              suffix: 'm',
              onChanged: _onRollLengthChanged,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _numberField(
        controller: _repeatController,
        label: L10n.get('materials_pattern_repeat_cm'),
        suffix: 'cm',
        onChanged: _onRepeatChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = _project;
    if (project == null || (widget.roomId != null && _room == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(L10n.get('project_not_found'))),
      );
    }

    final scan = _scan;

    // Floor: tile estimate + plinth from the footprint.
    final floorArea = FloorTileEstimator.resolveFloorAreaM2(
      floorAreaM2: scan?.floorAreaM2,
      floorLongM: scan?.floorLongM,
      floorShortM: scan?.floorShortM,
    );
    final floorAreaApprox = FloorTileEstimator.usedBoundingFallback(
      floorAreaM2: scan?.floorAreaM2,
      floorLongM: scan?.floorLongM,
      floorShortM: scan?.floorShortM,
    );
    // True wall-run perimeter measured by the backend from the GLB; null for
    // scans that predate the metric (fall back to the OBB approximation).
    final measuredPerimeterM =
        (scan?.wallPerimeterM != null && scan!.wallPerimeterM! > 0)
        ? scan.wallPerimeterM
        : null;
    final obbPerimeterM = FloorTileEstimator.resolvePerimeterM(
      floorLongM: scan?.floorLongM,
      floorShortM: scan?.floorShortM,
    );

    // Plinth: wall perimeter minus door/opening widths when measured,
    // otherwise the OBB perimeter with doorways not subtracted.
    final double? plinthPerimeterM;
    final String plinthNote;
    if (measuredPerimeterM != null) {
      final doorwayWidth = (scan?.doorwayWidthM ?? 0) > 0
          ? scan!.doorwayWidthM!
          : 0.0;
      plinthPerimeterM = (measuredPerimeterM - doorwayWidth) > 0
          ? measuredPerimeterM - doorwayWidth
          : 0.0;
      plinthNote = doorwayWidth > 0
          ? L10n.get('materials_plinth_minus_doorways_template')
                .replaceAll('{length}', measuredPerimeterM.toStringAsFixed(1))
                .replaceAll('{doorways}', doorwayWidth.toStringAsFixed(1))
          : L10n.get('materials_plinth_no_doorways');
    } else {
      plinthPerimeterM = obbPerimeterM;
      plinthNote = L10n.get('materials_plinth_note');
    }

    // Walls: wallpaper strips from perimeter × wall height.
    final perimeterM = measuredPerimeterM ?? obbPerimeterM;
    final wallHeightM = (scan?.heightM != null && scan!.heightM! > 0)
        ? scan.heightM
        : null;

    // Opening face areas measured by the backend; null when unmeasured, so
    // the honest "not subtracted" note can be shown instead.
    final openingAreaM2 =
        (scan?.doorwayAreaM2 != null || scan?.windowAreaM2 != null)
        ? (scan?.doorwayAreaM2 ?? 0) + (scan?.windowAreaM2 ?? 0)
        : null;

    final tileEstimate = floorArea == null
        ? null
        : FloorTileEstimator.estimate(
            floorAreaM2: floorArea,
            widthCm: _widthCm,
            heightCm: _heightCm,
            wastePercent: _wastePercent,
            usedBoundingFallback: floorAreaApprox,
          );
    final wallpaperEstimate = (perimeterM == null || wallHeightM == null)
        ? null
        : FloorTileEstimator.estimateWallpaper(
            perimeterM: perimeterM,
            wallHeightM: wallHeightM,
            rollWidthM: _rollWidthM,
            rollLengthM: _rollLengthM,
            repeatCm: _repeatCm,
          );

    final hasMeasurements = _walls
        ? (perimeterM != null && wallHeightM != null)
        : floorArea != null;
    final noAreaKey = _walls
        ? 'materials_walls_no_area'
        : 'materials_floor_no_area';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L10n.get(
            _walls ? 'materials_wallpaper_title' : 'materials_floor_title',
          ),
        ),
      ),
      body: KeyboardDismissScope(
        child: ListView(
          keyboardDismissBehavior: KeyboardDismissScope.scrollBehavior,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              _title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.showSurfaceSelector) ...[
              SegmentedButton<MaterialsSurface>(
                segments: [
                  ButtonSegment<MaterialsSurface>(
                    value: MaterialsSurface.floor,
                    label: Text(L10n.get('materials_floor_surface')),
                  ),
                  ButtonSegment<MaterialsSurface>(
                    value: MaterialsSurface.walls,
                    label: Text(L10n.get('materials_walls_surface')),
                  ),
                ],
                selected: {_surface},
                onSelectionChanged: (next) {
                  if (next.isEmpty) return;
                  _setSurface(next.first);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (!hasMeasurements)
              Text(
                L10n.get(noAreaKey),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else if (_walls) ...[
              Text(
                L10n.get('materials_perimeter_height_template')
                    .replaceAll('{perimeter}', perimeterM!.toStringAsFixed(1))
                    .replaceAll('{height}', wallHeightM!.toStringAsFixed(2)),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _wallOpeningsNote(
                  perimeterM: perimeterM,
                  wallHeightM: wallHeightM,
                  openingAreaM2: openingAreaM2,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Text(
                L10n.get(
                  'materials_floor_area_template',
                ).replaceAll('{area}', floorArea!.toStringAsFixed(1)),
                style: theme.textTheme.bodyLarge,
              ),
              if (floorAreaApprox) ...[
                const SizedBox(height: 4),
                Text(
                  L10n.get('materials_floor_area_approx'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            ...(_walls
                ? _buildWallpaperControls(theme)
                : _buildFloorControls(theme)),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _walls
                    ? _buildWallpaperResult(theme, wallpaperEstimate, noAreaKey)
                    : _buildTileResult(
                        theme,
                        tileEstimate,
                        plinthPerimeterM,
                        plinthNote,
                        noAreaKey,
                        tileEstimate == null
                            ? null
                            : () => _openTileLayout(tileEstimate),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Net wall area when the backend measured opening areas; the honest
  /// "not subtracted" disclaimer for scans that predate the metric. The roll
  /// count stays strip-based over the full perimeter — strips still run
  /// above doors and around windows.
  String _wallOpeningsNote({
    required double perimeterM,
    required double wallHeightM,
    required double? openingAreaM2,
  }) {
    if (openingAreaM2 == null) return L10n.get('materials_openings_note');
    final grossM2 = perimeterM * wallHeightM;
    final netM2 = (grossM2 - openingAreaM2) > 0 ? grossM2 - openingAreaM2 : 0.0;
    if (openingAreaM2 > 0.05) {
      return L10n.get('materials_wall_net_area_template')
          .replaceAll('{net}', netM2.toStringAsFixed(1))
          .replaceAll('{openings}', openingAreaM2.toStringAsFixed(1));
    }
    return L10n.get(
      'materials_wall_no_openings_template',
    ).replaceAll('{net}', netM2.toStringAsFixed(1));
  }

  Widget _buildTileResult(
    ThemeData theme,
    FloorTileEstimate? estimate,
    double? plinthPerimeterM,
    String plinthNote,
    String noAreaKey,
    VoidCallback? onOpenLayout,
  ) {
    if (estimate == null) {
      return Text(L10n.get(noAreaKey), style: theme.textTheme.bodyLarge);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10n.get('materials_result_heading'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Text(
          L10n.get(
            'materials_result_tiles_template',
          ).replaceAll('{count}', estimate.tileCount.toString()),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          L10n.get(
            'materials_result_buy_area_template',
          ).replaceAll('{area}', estimate.buyAreaM2.toStringAsFixed(1)),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          L10n.get('materials_result_detail_template')
              .replaceAll('{tileArea}', estimate.tileAreaM2.toStringAsFixed(2))
              .replaceAll(
                '{effectiveArea}',
                estimate.effectiveAreaM2.toStringAsFixed(1),
              ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (plinthPerimeterM != null && plinthPerimeterM > 0) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            L10n.get('materials_plinth_template')
                .replaceAll('{length}', plinthPerimeterM.toStringAsFixed(1))
                .replaceAll(
                  '{count}',
                  FloorTileEstimator.plinthStripCount(
                    plinthPerimeterM,
                  ).toString(),
                ),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plinthNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (onOpenLayout != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onOpenLayout,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.centerLeft,
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    L10n.get('materials_tile_layout_button'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWallpaperResult(
    ThemeData theme,
    WallpaperEstimate? estimate,
    String noAreaKey,
  ) {
    if (estimate == null) {
      return Text(L10n.get(noAreaKey), style: theme.textTheme.bodyLarge);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10n.get('materials_result_heading'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Text(
          L10n.get(
            'materials_result_rolls_template',
          ).replaceAll('{count}', estimate.rollCount.toString()),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          L10n.get('materials_result_strips_template')
              .replaceAll('{strips}', estimate.stripsNeeded.toString())
              .replaceAll(
                '{stripLength}',
                estimate.stripLengthM.toStringAsFixed(2),
              ),
          style: theme.textTheme.bodyLarge,
        ),
        if (estimate.stripsPerRoll >= 1) ...[
          const SizedBox(height: 8),
          Text(
            L10n.get(
              'materials_strips_per_roll_template',
            ).replaceAll('{count}', estimate.stripsPerRoll.toString()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
