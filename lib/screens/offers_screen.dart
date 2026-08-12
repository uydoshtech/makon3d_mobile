import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/contractor_job.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/screens/contractor_jobs_feed_screen.dart';
import 'package:makon3d_mobile/screens/customer_contractor_job_screen.dart';
import 'package:makon3d_mobile/services/auth/auth_state.dart';
import 'package:makon3d_mobile/services/contractor_marketplace_service.dart';
import 'package:makon3d_mobile/theme/makon_colors.dart';
import 'package:makon3d_mobile/widgets/app_bar_account_avatar.dart';
import 'package:makon3d_mobile/widgets/makonix_loader.dart';

/// Customer-facing contractor responses and contractor-facing submitted bids.
/// Replaces the old standalone scan gallery tab; scans remain inside projects.
class OffersScreen extends StatefulWidget {
  const OffersScreen({
    required this.isActive,
    required this.isContractor,
    this.onOpenAccount,
    super.key,
  });

  final bool isActive;
  final bool isContractor;
  final VoidCallback? onOpenAccount;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<ContractorJob> _jobs = const <ContractorJob>[];
  bool _loading = false;
  bool _failed = false;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant OffersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isActive && !oldWidget.isActive) ||
        widget.isContractor != oldWidget.isContractor) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!AuthState().isSignedIn) {
      if (!mounted) return;
      setState(() {
        _jobs = const <ContractorJob>[];
        _loading = false;
        _failed = false;
        _loadedOnce = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final jobs = widget.isContractor
          ? await ContractorMarketplaceService.listMyOffers()
          : await ContractorMarketplaceService.listMine();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
        _loadedOnce = true;
      });
    }
  }

  Future<void> _open(ContractorJob job) async {
    if (widget.isContractor) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ContractorJobDetailScreen(jobId: job.id),
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomerContractorJobScreen(
            projectId: job.projectId ?? '',
            jobId: job.id,
          ),
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = widget.isContractor
        ? 'offers_submitted_title'
        : 'offers_list_title';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          L10n.get(titleKey),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (widget.onOpenAccount case final onOpenAccount?)
            AppBarAccountAvatar(onTap: onOpenAccount),
        ],
      ),
      body: !AuthState().isSignedIn
          ? _Message(
              icon: Icons.lock_outline,
              text: L10n.get('offers_sign_in_required'),
            )
          : _loading && !_loadedOnce
          ? const Center(child: MakonixLoader())
          : _failed
          ? _Message(
              icon: Icons.cloud_off_outlined,
              text: L10n.get('offers_load_failed'),
              action: () => unawaited(_load()),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _jobs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(32, 120, 32, 120),
                      children: [
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              color: MakonColors.yellowSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.handshake_outlined,
                              size: 36,
                              color: MakonColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          L10n.get(
                            widget.isContractor
                                ? 'offers_submitted_empty'
                                : 'offers_empty',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        return _OfferJobCard(
                          job: job,
                          isContractor: widget.isContractor,
                          onTap: () => unawaited(_open(job)),
                        );
                      },
                    ),
            ),
    );
  }
}

class _OfferJobCard extends StatelessWidget {
  const _OfferJobCard({
    required this.job,
    required this.isContractor,
    required this.onTap,
  });

  final ContractorJob job;
  final bool isContractor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = job.projectName?.trim().isNotEmpty == true
        ? job.projectName!
        : L10n.get('offers_project_fallback');
    final status = switch (job.status) {
      ContractorListingStatus.open => L10n.get('contractor_publication_active'),
      ContractorListingStatus.assigned => L10n.get(
        'contractor_status_assigned',
      ),
      ContractorListingStatus.closed ||
      ContractorListingStatus.cancelled => L10n.get('contractor_status_closed'),
    };
    final subtitle = isContractor
        ? _contractorOfferSummary(job)
        : L10n.get(
            'contractor_offers_count',
          ).replaceAll('{count}', '${job.offerCount}');
    final statusColor = switch (job.status) {
      ContractorListingStatus.open => const Color(0xFF2E7D32),
      ContractorListingStatus.assigned => const Color(0xFF9A6B00),
      ContractorListingStatus.closed ||
      ContractorListingStatus.cancelled => theme.colorScheme.onSurfaceVariant,
    };
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: theme.colorScheme.secondary,
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  size: 23,
                  color: MakonColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (job.publicLocation.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              job.publicLocation,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          subtitle,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                status,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _contractorOfferSummary(ContractorJob job) {
    final offer = job.myOffer;
    if (offer == null) return L10n.get('contractor_offer_sent');
    final amount = offer.amountMillion;
    final price = amount == null ? '—' : amount.toStringAsFixed(1);
    return '$price ${L10n.get('contractor_budget_unit')} · '
        '${L10n.get('offers_duration_days').replaceAll('{count}', '${offer.durationDays}')}';
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: MakonColors.yellowSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: MakonColors.ink),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(L10n.get('contractor_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
