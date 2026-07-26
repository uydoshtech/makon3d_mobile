import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/screens/project_dashboard_screen.dart';
import 'package:makon3d_mobile/screens/scan_mode_selection_screen.dart';
import 'package:makon3d_mobile/services/geocode_service.dart';
import 'package:makon3d_mobile/services/makon_analytics.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/address_suggest_field.dart';
import 'package:makon3d_mobile/widgets/keyboard_dismiss_scope.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

String _newProjectId() {
  final r = Random.secure();
  final a = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final b = List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  return '$a-$b';
}

/// Step 1: project metadata → Step 2: scan mode → dashboard.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;
  bool _locating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _continueToMode() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Toasts.showInfo(context, L10n.get('project_name_required'));
      return;
    }

    final mode = await Navigator.of(context).push<ScanMode>(
      MaterialPageRoute<ScanMode>(
        builder: (_) =>
            const ScanModeSelectionScreen(entryPoint: 'new_project'),
      ),
    );
    if (mode == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final project = MakonProject(
        id: _newProjectId(),
        name: name,
        scanMode: mode,
        createdAt: DateTime.now(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await MakonProjectStore.instance.upsert(project);
      MakonAnalytics.scanModeSelected(
        projectId: project.id,
        scanMode: mode,
        entryPoint: 'new_project',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProjectDashboardScreen(projectId: project.id),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('project_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Fills the address field from the device location — mirrors the UyDosh
  /// create-listing flow (service check → permission → position → reverse
  /// geocode via the backend's Yandex proxy).
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
      _addressController.text = address;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.get('project_new_title'))),
      body: SafeArea(
        child: KeyboardDismissScope(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: KeyboardDismissScope.scrollBehavior,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: L10n.get('project_name_label'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AddressSuggestField(
                      controller: _addressController,
                      suffixIcon: _locating
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: L10n.get('use_current_location'),
                              icon: const Icon(Icons.my_location),
                              onPressed: () => unawaited(_useCurrentLocation()),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: L10n.get('project_notes_label'),
                        helperText: L10n.get('project_notes_optional_hint'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () {
                            KeyboardDismissScope.dismiss();
                            _continueToMode();
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(L10n.get('project_continue_to_mode')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
