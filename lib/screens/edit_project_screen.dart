import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/geocode_service.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/address_suggest_field.dart';
import 'package:makon3d_mobile/widgets/keyboard_dismiss_scope.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Updates a project's user-provided metadata without changing its scan mode.
class EditProjectScreen extends StatefulWidget {
  const EditProjectScreen({required this.project, super.key});

  final MakonProject project;

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _addressController = TextEditingController(
      text: widget.project.address ?? '',
    );
    _notesController = TextEditingController(text: widget.project.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Toasts.showInfo(context, L10n.get('project_name_required'));
      return;
    }

    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();
    setState(() => _saving = true);
    try {
      await MakonProjectStore.instance.upsert(
        widget.project.copyWith(
          name: name,
          address: address.isEmpty ? null : address,
          notes: notes.isEmpty ? null : notes,
          clearAddress: address.isEmpty,
          clearNotes: notes.isEmpty,
        ),
      );
      if (!mounted) return;
      Toasts.showSuccess(context, L10n.get('project_saved'));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('project_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
      appBar: AppBar(title: Text(L10n.get('project_edit'))),
      body: SafeArea(
        child: KeyboardDismissScope(
          child: ListView(
            keyboardDismissBehavior: KeyboardDismissScope.scrollBehavior,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () {
                        KeyboardDismissScope.dismiss();
                        _save();
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
                    : Text(L10n.get('project_save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
