import 'package:flutter/material.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/scan_flow/makon_product.dart';
import 'package:makon3d_mobile/services/makon_analytics.dart';

/// Makon-only: choose entire housing vs room-by-room.
class ScanModeSelectionScreen extends StatefulWidget {
  const ScanModeSelectionScreen({
    super.key,
    this.projectId,
    this.entryPoint = 'new_project',
    this.initialMode,
  });

  final String? projectId;
  final String entryPoint;
  final ScanMode? initialMode;

  @override
  State<ScanModeSelectionScreen> createState() =>
      _ScanModeSelectionScreenState();
}

class _ScanModeSelectionScreenState extends State<ScanModeSelectionScreen> {
  late ScanMode? _selected;

  @override
  void initState() {
    super.initState();
    final modes = ScanModePolicy.availableModes(
      forProduct: kMakonScanEntry.product,
    );
    // Default to entire housing; user can still pick room-by-room.
    _selected =
        widget.initialMode ??
        (modes.contains(ScanMode.entireHousing)
            ? ScanMode.entireHousing
            : modes.first);
    MakonAnalytics.scanModeScreenViewed(
      projectId: widget.projectId,
      entryPoint: widget.entryPoint,
    );
  }

  IconData _iconFor(ScanMode mode) {
    return switch (mode) {
      ScanMode.entireHousing => Icons.home_outlined,
      ScanMode.roomByRoom => Icons.view_in_ar,
    };
  }

  void _continue() {
    final mode = _selected;
    if (mode == null) return;
    if (widget.projectId != null) {
      MakonAnalytics.scanModeSelected(
        projectId: widget.projectId!,
        scanMode: mode,
        entryPoint: widget.entryPoint,
      );
    }
    Navigator.of(context).pop(mode);
  }

  @override
  Widget build(BuildContext context) {
    final modes = ScanModePolicy.availableModes(
      forProduct: kMakonScanEntry.product,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.get('scan_mode_choose_title'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                L10n.get('scan_mode_choose_subtitle'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: modes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final mode = modes[index];
                    final selected = _selected == mode;
                    final showBadge = mode == ScanMode.roomByRoom;
                    return Material(
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _selected = mode),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                _iconFor(mode),
                                size: 32,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            L10n.get(mode.titleKey),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        if (selected)
                                          Icon(
                                            Icons.check_circle,
                                            color: theme.colorScheme.primary,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      L10n.get(mode.detailKey),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    if (showBadge) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          L10n.get(
                                            'scan_mode_recommended_badge',
                                          ),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSecondary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected == null ? null : _continue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(L10n.get('scan_mode_continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
