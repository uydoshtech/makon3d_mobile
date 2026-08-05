import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/contractor_job.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/services/contractor_marketplace_service.dart';
import 'package:makon3d_mobile/theme/makon_colors.dart';
import 'package:makon3d_mobile/widgets/app_bar_account_avatar.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

class ContractorJobsFeedScreen extends StatefulWidget {
  const ContractorJobsFeedScreen({super.key, this.onOpenAccount});

  final VoidCallback? onOpenAccount;

  @override
  State<ContractorJobsFeedScreen> createState() =>
      _ContractorJobsFeedScreenState();
}

class _ContractorJobsFeedScreenState extends State<ContractorJobsFeedScreen> {
  List<ContractorJob> _jobs = const <ContractorJob>[];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _failed = false);
    try {
      final results = await Future.wait<List<ContractorJob>>([
        ContractorMarketplaceService.listMyOffers(),
        ContractorMarketplaceService.listFeed(),
      ]);
      final byId = <int, ContractorJob>{};
      for (final job in [...results[0], ...results[1]]) {
        byId.putIfAbsent(job.id, () => job);
      }
      if (!mounted) return;
      setState(() {
        _jobs = byId.values.toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openJob(ContractorJob job) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContractorJobDetailScreen(jobId: job.id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get('contractor_feed_title')),
        actions: [
          if (widget.onOpenAccount case final onOpenAccount?)
            AppBarAccountAvatar(onTap: onOpenAccount),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? _FeedMessage(
              icon: Icons.cloud_off_outlined,
              message: L10n.get('contractor_feed_failed'),
              actionLabel: L10n.get('contractor_retry'),
              onAction: () => unawaited(_load()),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _jobs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(32, 110, 32, 120),
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 54,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          L10n.get('contractor_feed_empty'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ContractorJobCard(
                        job: _jobs[index],
                        onTap: () => unawaited(_openJob(_jobs[index])),
                      ),
                    ),
            ),
    );
  }
}

class ContractorJobDetailScreen extends StatefulWidget {
  const ContractorJobDetailScreen({required this.jobId, super.key});

  final int jobId;

  @override
  State<ContractorJobDetailScreen> createState() =>
      _ContractorJobDetailScreenState();
}

class _ContractorJobDetailScreenState extends State<ContractorJobDetailScreen> {
  ContractorJob? _job;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final job = await ContractorMarketplaceService.getJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openOffer() async {
    final job = _job;
    if (job == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OfferSheet(job: job),
    );
    if (saved == true) {
      if (mounted) {
        Toasts.showSuccess(context, L10n.get('contractor_offer_saved'));
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      appBar: AppBar(title: Text(L10n.get('contractor_job_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed || job == null
          ? _FeedMessage(
              icon: Icons.cloud_off_outlined,
              message: L10n.get('contractor_job_failed'),
              actionLabel: L10n.get('contractor_retry'),
              onAction: () => unawaited(_load()),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                _JobHeader(job: job),
                const SizedBox(height: 18),
                _SectionCard(
                  title: L10n.get('contractor_job_work'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in job.workTypes)
                        Chip(label: Text(_workLabel(type))),
                    ],
                  ),
                ),
                if (job.detectedVolumes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: L10n.get('contractor_job_quantities'),
                    child: Column(
                      children: [
                        for (final volume in job.detectedVolumes)
                          _ValueRow(
                            label: _workLabel(volume.type),
                            value: _volumeText(volume),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SectionCard(
                  title: L10n.get('contractor_job_terms'),
                  child: Column(
                    children: [
                      _ValueRow(
                        label: L10n.get('contractor_preview_budget'),
                        value: _budgetText(job),
                      ),
                      _ValueRow(
                        label: L10n.get('contractor_start_date'),
                        value: _dateText(job.startDate),
                      ),
                      _ValueRow(
                        label: L10n.get('contractor_duration'),
                        value: L10n.get(
                          'contractor_duration_days',
                        ).replaceAll('{count}', '${job.durationDays}'),
                      ),
                    ],
                  ),
                ),
                if (job.comment case final comment?) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: L10n.get('contractor_comment'),
                    child: Text(comment),
                  ),
                ],
                if (job.privateAccess case final access?) ...[
                  const SizedBox(height: 12),
                  _PrivateAccessCard(access: access),
                ],
                const SizedBox(height: 24),
                if (job.myOffer?.isAccepted == true)
                  _StatusBanner(
                    icon: Icons.verified_outlined,
                    text: job.contactRevealed
                        ? L10n.get('contractor_offer_accepted_access')
                        : L10n.get('contractor_offer_accepted_wait'),
                  )
                else if (job.isOpen)
                  FilledButton.icon(
                    onPressed: () => unawaited(_openOffer()),
                    icon: Icon(
                      job.myOffer == null
                          ? Icons.send_outlined
                          : Icons.edit_outlined,
                    ),
                    label: Text(
                      L10n.get(
                        job.myOffer == null
                            ? 'contractor_offer_send'
                            : 'contractor_offer_edit',
                      ),
                    ),
                  )
                else
                  _StatusBanner(
                    icon: Icons.info_outline,
                    text: L10n.get('contractor_job_unavailable'),
                  ),
              ],
            ),
    );
  }
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.job});

  final ContractorJob job;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _days;
  late final TextEditingController _warranty;
  late final TextEditingController _comment;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final offer = widget.job.myOffer;
    _amount = TextEditingController(text: _inputNumber(offer?.amountMillion));
    _days = TextEditingController(
      text:
          offer?.durationDays.toString() ?? widget.job.durationDays.toString(),
    );
    _warranty = TextEditingController(
      text: offer?.warrantyMonths?.toString() ?? '',
    );
    _comment = TextEditingController(text: offer?.comment ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _days.dispose();
    _warranty.dispose();
    _comment.dispose();
    super.dispose();
  }

  bool get _valid {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final days = int.tryParse(_days.text.trim());
    final warranty = _warranty.text.trim().isEmpty
        ? 1
        : int.tryParse(_warranty.text.trim());
    return amount != null &&
        amount > 0 &&
        days != null &&
        days > 0 &&
        warranty != null &&
        warranty > 0;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ContractorMarketplaceService.submitOffer(
        jobId: widget.job.id,
        amountMillion: double.parse(_amount.text.trim().replaceAll(',', '.')),
        durationDays: int.parse(_days.text.trim()),
        warrantyMonths: _warranty.text.trim().isEmpty
            ? null
            : int.parse(_warranty.text.trim()),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      Toasts.showError(context, L10n.get('contractor_offer_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + insets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              L10n.get('contractor_offer_title'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: L10n.get('contractor_offer_price'),
                suffixText: L10n.get('contractor_budget_unit'),
                errorText: _showErrors && !_valid
                    ? L10n.get('contractor_offer_check_fields')
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _days,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: L10n.get('contractor_offer_days'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _warranty,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: L10n.get('contractor_offer_warranty'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: L10n.get('contractor_offer_comment'),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_save()),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(L10n.get('contractor_offer_submit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractorJobCard extends StatelessWidget {
  const _ContractorJobCard({required this.job, required this.onTap});

  final ContractorJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.publicLocation,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (job.roomCount != null)
                    L10n.get(
                      'contractor_job_rooms',
                    ).replaceAll('{count}', '${job.roomCount}'),
                  if (job.areaM2 != null) '${_number(job.areaM2!)} m²',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                job.workTypes.map(_workLabel).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _budgetText(job),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (job.myOffer != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: MakonColors.yellowSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        L10n.get(
                          job.myOffer?.isAccepted == true
                              ? 'contractor_offer_selected'
                              : 'contractor_offer_sent',
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.job});

  final ContractorJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MakonColors.yellowSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.get('contractor_preview_order_title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 20),
              const SizedBox(width: 7),
              Expanded(child: Text(job.publicLocation)),
            ],
          ),
          if (job.areaM2 != null || job.roomCount != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (job.roomCount != null)
                  L10n.get(
                    'contractor_job_rooms',
                  ).replaceAll('{count}', '${job.roomCount}'),
                if (job.areaM2 != null) '${_number(job.areaM2!)} m²',
              ].join(' · '),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivateAccessCard extends StatelessWidget {
  const _PrivateAccessCard({required this.access});

  final ContractorPrivateAccess access;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: L10n.get('contractor_private_access_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (access.customerName case final name?) Text(name),
          if (access.customerPhone case final phone?) ...[
            const SizedBox(height: 8),
            SelectableText(
              phone,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (access.exactAddress case final address?) ...[
            const SizedBox(height: 8),
            Text(address),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MakonColors.yellowSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _workLabel(ContractorWorkType type) => L10n.get(switch (type) {
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

String _budgetText(ContractorJob job) {
  if (job.budgetMode != ContractorBudgetMode.range ||
      job.budgetMinMillion == null ||
      job.budgetMaxMillion == null) {
    return L10n.get('contractor_budget_open_value');
  }
  return '${_number(job.budgetMinMillion!)}–${_number(job.budgetMaxMillion!)} '
      '${L10n.get('contractor_budget_unit')}';
}

String _volumeText(ContractorWorkVolume volume) {
  final unit = switch (volume.unit) {
    ContractorVolumeUnit.squareMeters => 'm²',
    ContractorVolumeUnit.meters => 'm',
    ContractorVolumeUnit.pieces => L10n.get('contractor_unit_pieces'),
  };
  return '${_number(volume.amount)} $unit';
}

String _dateText(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _inputNumber(double? value) => value == null ? '' : _number(value);
