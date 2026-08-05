import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/contractor_job.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/screens/contractor_listing_flow_screen.dart';
import 'package:makon3d_mobile/services/contractor_marketplace_service.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/theme/makon_colors.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

class CustomerContractorJobScreen extends StatefulWidget {
  const CustomerContractorJobScreen({
    required this.projectId,
    required this.jobId,
    super.key,
  });

  final String projectId;
  final int jobId;

  @override
  State<CustomerContractorJobScreen> createState() =>
      _CustomerContractorJobScreenState();
}

class _CustomerContractorJobScreenState
    extends State<CustomerContractorJobScreen> {
  ContractorJob? _job;
  bool _loading = true;
  bool _failed = false;
  bool _acting = false;

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
      await _syncListing(job);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _syncListing(ContractorJob job) async {
    final project = MakonProjectStore.instance.getById(widget.projectId);
    final listing = project?.contractorListing;
    if (project == null || listing == null) return;
    if (listing.responseCount == job.offerCount &&
        listing.status == job.status &&
        listing.remoteJobId == job.id) {
      return;
    }
    await MakonProjectStore.instance.upsert(
      project.copyWith(
        contractorListing: listing.copyWith(
          remoteJobId: job.id,
          responseCount: job.offerCount,
          status: job.status,
        ),
      ),
    );
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ContractorListingFlowScreen(projectId: widget.projectId),
      ),
    );
    await _load();
  }

  Future<void> _accept(ContractorOffer offer) async {
    if (_acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.get('contractor_accept_title')),
        content: Text(
          L10n.get('contractor_accept_message').replaceAll(
            '{name}',
            offer.contractorName ?? L10n.get('contractor_offer_specialist'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(L10n.get('contractor_accept_action')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await ContractorMarketplaceService.acceptOffer(offer.id);
      await _load();
      if (mounted) {
        Toasts.showSuccess(context, L10n.get('contractor_accept_done'));
      }
    } catch (_) {
      if (mounted) {
        Toasts.showError(context, L10n.get('contractor_accept_failed'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reveal() async {
    if (_acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.get('contractor_reveal_title')),
        content: Text(L10n.get('contractor_reveal_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(L10n.get('contractor_reveal_action')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await ContractorMarketplaceService.revealPrivateAccess(widget.jobId);
      await _load();
      if (mounted) {
        Toasts.showSuccess(context, L10n.get('contractor_reveal_done'));
      }
    } catch (_) {
      if (mounted) {
        Toasts.showError(context, L10n.get('contractor_reveal_failed'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _close() async {
    if (_acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.get('contractor_close_title')),
        content: Text(L10n.get('contractor_close_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(L10n.get('contractor_close_action')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await ContractorMarketplaceService.closeJob(widget.jobId);
      await _load();
    } catch (_) {
      if (mounted) {
        Toasts.showError(context, L10n.get('contractor_close_failed'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get('contractor_responses_title')),
        actions: [
          if (job?.isOpen == true)
            IconButton(
              tooltip: L10n.get('contractor_edit_listing'),
              onPressed: _acting ? null : () => unawaited(_edit()),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (job?.isOpen == true)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'close') unawaited(_close());
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'close',
                  child: Text(L10n.get('contractor_close_action')),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed || job == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      L10n.get('contractor_responses_failed'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => unawaited(_load()),
                      child: Text(L10n.get('contractor_retry')),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _PublicationSummary(job: job),
                  if (job.isAssigned) ...[
                    const SizedBox(height: 12),
                    _SelectionStatus(
                      isRevealed: job.contactRevealed,
                      onReveal: _acting || job.contactRevealed
                          ? null
                          : () => unawaited(_reveal()),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    L10n.get(
                      'contractor_offers_count',
                    ).replaceAll('{count}', '${job.offerCount}'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (job.offers.isEmpty)
                    _EmptyOffers()
                  else
                    for (final offer in job.offers) ...[
                      _OwnerOfferCard(
                        offer: offer,
                        canAccept: job.isOpen && offer.isPending && !_acting,
                        onAccept: () => unawaited(_accept(offer)),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

class _PublicationSummary extends StatelessWidget {
  const _PublicationSummary({required this.job});

  final ContractorJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = switch (job.status) {
      ContractorListingStatus.open => L10n.get('contractor_publication_active'),
      ContractorListingStatus.assigned => L10n.get(
        'contractor_status_assigned',
      ),
      ContractorListingStatus.closed => L10n.get('contractor_status_closed'),
      ContractorListingStatus.cancelled => L10n.get('contractor_status_closed'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MakonColors.yellowSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined),
              const SizedBox(width: 9),
              Text(
                statusText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job.projectName ?? L10n.get('contractor_preview_order_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(job.publicLocation),
        ],
      ),
    );
  }
}

class _SelectionStatus extends StatelessWidget {
  const _SelectionStatus({required this.isRevealed, required this.onReveal});

  final bool isRevealed;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isRevealed ? Icons.lock_open_outlined : Icons.verified_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L10n.get(
                    isRevealed
                        ? 'contractor_access_revealed'
                        : 'contractor_selected_title',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (!isRevealed) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onReveal,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(L10n.get('contractor_reveal_action')),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerOfferCard extends StatelessWidget {
  const _OwnerOfferCard({
    required this.offer,
    required this.canAccept,
    required this.onAccept,
  });

  final ContractorOffer offer;
  final bool canAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        offer.contractorName ?? L10n.get('contractor_offer_specialist');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: offer.isAccepted
            ? MakonColors.yellowSoft
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: offer.isAccepted ? Border.all(color: MakonColors.yellow) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(name.characters.first.toUpperCase())),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (offer.isAccepted)
                const Icon(Icons.verified, color: Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OfferMetric(
                  label: L10n.get('contractor_offer_price'),
                  value:
                      '${_number(offer.amountMillion ?? 0)} ${L10n.get('contractor_budget_unit')}',
                ),
              ),
              Expanded(
                child: _OfferMetric(
                  label: L10n.get('contractor_offer_days'),
                  value: '${offer.durationDays}',
                ),
              ),
              if (offer.warrantyMonths != null)
                Expanded(
                  child: _OfferMetric(
                    label: L10n.get('contractor_offer_warranty_short'),
                    value: L10n.get(
                      'contractor_months',
                    ).replaceAll('{count}', '${offer.warrantyMonths}'),
                  ),
                ),
            ],
          ),
          if (offer.comment case final comment?) ...[
            const SizedBox(height: 14),
            Text(comment),
          ],
          if (canAccept) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAccept,
                child: Text(L10n.get('contractor_accept_action')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferMetric extends StatelessWidget {
  const _OfferMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_outlined, size: 38),
          const SizedBox(height: 12),
          Text(
            L10n.get('contractor_offers_empty'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
