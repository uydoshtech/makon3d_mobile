import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/floor_tile_prefs.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/services/floor_tile_estimate.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/keyboard_dismiss_scope.dart';

/// Surface whose tile quantity is being estimated.
enum MaterialsSurface { floor, walls }

/// Per-room (or entire-housing) tile quantity estimate for floor or walls.
class RoomMaterialsScreen extends StatefulWidget {
  const RoomMaterialsScreen({
    required this.projectId,
    this.roomId,
    this.initialSurface = MaterialsSurface.floor,
    super.key,
  });

  final String projectId;

  /// Null = entire-housing project (one measured space).
  final String? roomId;

  final MaterialsSurface initialSurface;

  @override
  State<RoomMaterialsScreen> createState() => _RoomMaterialsScreenState();
}

class _Preset {
  const _Preset(this.widthCm, this.heightCm);
  final double widthCm;
  final double heightCm;

  bool matches(double w, double h) =>
      (w - widthCm).abs() < 0.001 && (h - heightCm).abs() < 0.001;
}

class _RoomMaterialsScreenState extends State<RoomMaterialsScreen> {
  static const _squarePresets = <_Preset>[
    _Preset(30, 30),
    _Preset(40, 40),
    _Preset(60, 60),
  ];
  static const _rectPresets = <_Preset>[
    _Preset(20, 30),
    _Preset(30, 60),
    _Preset(40, 50),
  ];

  late MaterialsSurface _surface;
  late bool _isSquare;
  late double _widthCm;
  late double _heightCm;
  late double _wastePercent;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _surface = widget.initialSurface;
    final prefs = _loadPrefs(_surface);
    _isSquare = prefs.isSquare;
    _widthCm = prefs.widthCm;
    _heightCm = prefs.heightCm;
    _wastePercent = prefs.wastePercent;
    _widthController = TextEditingController(
      text: _formatCm(_widthCm),
    );
    _heightController = TextEditingController(
      text: _formatCm(_heightCm),
    );
    MakonProjectStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    MakonProjectStore.instance.removeListener(_onStoreChanged);
    _widthController.dispose();
    _heightController.dispose();
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

  FloorTilePrefs _loadPrefs(MaterialsSurface surface) {
    final fallback = surface == MaterialsSurface.walls
        ? FloorTilePrefs.wallDefaults
        : FloorTilePrefs.defaults;
    if (widget.roomId != null) {
      final room = _room;
      return (surface == MaterialsSurface.walls
              ? room?.wallTilePrefs
              : room?.floorTilePrefs) ??
          fallback;
    }
    final project = _project;
    return (surface == MaterialsSurface.walls
            ? project?.entireHousingWallTilePrefs
            : project?.entireHousingFloorTilePrefs) ??
        fallback;
  }

  String get _title {
    final room = _room;
    if (room != null) {
      if (room.name?.isNotEmpty == true) return room.name!;
      return L10n.get(room.roomType.titleKey);
    }
    return _project?.name ?? L10n.get('project_action_materials');
  }

  String _formatCm(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  void _setSurface(MaterialsSurface surface) {
    if (surface == _surface) return;
    KeyboardDismissScope.dismiss();
    // Flush pending edits for the surface we are leaving.
    _persistDebounce?.cancel();
    unawaited(_persistPrefs(_surface));
    final prefs = _loadPrefs(surface);
    setState(() {
      _surface = surface;
      _isSquare = prefs.isSquare;
      _widthCm = prefs.widthCm;
      _heightCm = prefs.heightCm;
      _wastePercent = prefs.wastePercent;
      _widthController.text = _formatCm(_widthCm);
      _heightController.text = _formatCm(_heightCm);
    });
  }

  void _applyPreset(_Preset preset) {
    KeyboardDismissScope.dismiss();
    setState(() {
      _widthCm = preset.widthCm;
      _heightCm = preset.heightCm;
      _isSquare = preset.widthCm == preset.heightCm;
      _widthController.text = _formatCm(_widthCm);
      _heightController.text = _formatCm(_heightCm);
    });
    _schedulePersist();
  }

  void _setSquare(bool square) {
    KeyboardDismissScope.dismiss();
    setState(() {
      _isSquare = square;
      if (square) {
        _heightCm = _widthCm;
        _heightController.text = _formatCm(_heightCm);
      }
    });
    _schedulePersist();
  }

  void _onWidthChanged(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    setState(() {
      _widthCm = parsed;
      if (_isSquare) {
        _heightCm = parsed;
        _heightController.text = _formatCm(parsed);
      }
    });
    _schedulePersist();
  }

  void _onHeightChanged(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
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
    final prefs = FloorTilePrefs(
      widthCm: _widthCm,
      heightCm: _heightCm,
      wastePercent: _wastePercent,
    );
    final walls = surface == MaterialsSurface.walls;
    if (widget.roomId != null) {
      final rooms = project.rooms.map((room) {
        if (room.id != widget.roomId) return room;
        return walls
            ? room.copyWith(wallTilePrefs: prefs)
            : room.copyWith(floorTilePrefs: prefs);
      }).toList(growable: false);
      await MakonProjectStore.instance.upsert(project.copyWith(rooms: rooms));
      return;
    }
    await MakonProjectStore.instance.upsert(
      walls
          ? project.copyWith(entireHousingWallTilePrefs: prefs)
          : project.copyWith(entireHousingFloorTilePrefs: prefs),
    );
  }

  /// Measured surface area in m², or null when the scan lacks the metrics.
  double? _resolveSurfaceArea(HousingScan? scan) {
    if (_surface == MaterialsSurface.walls) {
      return FloorTileEstimator.resolveWallAreaM2(
        floorLongM: scan?.floorLongM,
        floorShortM: scan?.floorShortM,
        heightM: scan?.heightM,
      );
    }
    return FloorTileEstimator.resolveFloorAreaM2(
      floorAreaM2: scan?.floorAreaM2,
      floorLongM: scan?.floorLongM,
      floorShortM: scan?.floorShortM,
    );
  }

  bool get _walls => _surface == MaterialsSurface.walls;

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
    final surfaceArea = _resolveSurfaceArea(scan);
    // Walls are always a bounding-box approximation (perimeter × height).
    final approximate = _walls
        ? surfaceArea != null
        : FloorTileEstimator.usedBoundingFallback(
            floorAreaM2: scan?.floorAreaM2,
            floorLongM: scan?.floorLongM,
            floorShortM: scan?.floorShortM,
          );
    final estimate = surfaceArea == null
        ? null
        : FloorTileEstimator.estimate(
            floorAreaM2: surfaceArea,
            widthCm: _widthCm,
            heightCm: _heightCm,
            wastePercent: _wastePercent,
            usedBoundingFallback: approximate,
          );

    final presets = _isSquare ? _squarePresets : _rectPresets;
    final noAreaKey =
        _walls ? 'materials_walls_no_area' : 'materials_floor_no_area';
    // Skirting board rides along with the floor surface only.
    final plinthPerimeterM = _walls
        ? null
        : FloorTileEstimator.resolvePerimeterM(
            floorLongM: scan?.floorLongM,
            floorShortM: scan?.floorShortM,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L10n.get(_walls ? 'materials_walls_title' : 'materials_floor_title'),
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
          if (surfaceArea != null)
            Text(
              L10n.get(
                _walls
                    ? 'materials_walls_area_template'
                    : 'materials_floor_area_template',
              ).replaceAll(
                '{area}',
                surfaceArea.toStringAsFixed(1),
              ),
              style: theme.textTheme.bodyLarge,
            )
          else
            Text(
              L10n.get(noAreaKey),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (approximate) ...[
            const SizedBox(height: 4),
            Text(
              L10n.get(
                _walls
                    ? 'materials_walls_area_approx'
                    : 'materials_floor_area_approx',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            L10n.get('materials_tile_shape'),
            style: theme.textTheme.titleSmall,
          ),
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
                    '${_formatCm(preset.widthCm)}×${_formatCm(preset.heightCm)}',
                  ),
                  selected: preset.matches(_widthCm, _heightCm),
                  onSelected: (_) => _applyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _widthController,
                  decoration: InputDecoration(
                    labelText: L10n.get('materials_tile_width_cm'),
                    suffixText: 'cm',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  onChanged: _onWidthChanged,
                ),
              ),
              if (!_isSquare) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    decoration: InputDecoration(
                      labelText: L10n.get('materials_tile_height_cm'),
                      suffixText: 'cm',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    onChanged: _onHeightChanged,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            L10n.get('materials_waste_label').replaceAll(
              '{percent}',
              _wastePercent.round().toString(),
            ),
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
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: estimate == null
                  ? Text(
                      L10n.get(noAreaKey),
                      style: theme.textTheme.bodyLarge,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.get('materials_result_heading'),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          L10n.get('materials_result_tiles_template')
                              .replaceAll(
                            '{count}',
                            estimate.tileCount.toString(),
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          L10n.get('materials_result_buy_area_template')
                              .replaceAll(
                            '{area}',
                            estimate.buyAreaM2.toStringAsFixed(1),
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          L10n.get('materials_result_detail_template')
                              .replaceAll(
                                '{tileArea}',
                                estimate.tileAreaM2.toStringAsFixed(2),
                              )
                              .replaceAll(
                                '{effectiveArea}',
                                estimate.effectiveAreaM2.toStringAsFixed(1),
                              ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (plinthPerimeterM != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Text(
                            L10n.get('materials_plinth_template')
                                .replaceAll(
                                  '{length}',
                                  plinthPerimeterM.toStringAsFixed(1),
                                )
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
                            L10n.get('materials_plinth_note'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
