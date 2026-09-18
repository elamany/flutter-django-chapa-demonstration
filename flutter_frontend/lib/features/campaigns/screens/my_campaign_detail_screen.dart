import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/format.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../donations/bloc/donor_latest_5_list_wall_bloc.dart';
import '../../donations/bloc/donorr_latest_5_list_wall_event.dart';
import '../../donations/widgets/donor_latest_5_list_wall_widget.dart';
import '../bloc/my_campaign_detail_bloc.dart';
import '../bloc/my_campaign_detail_event.dart';
import '../bloc/my_campaign_detail_state.dart';
import '../data/models/campaign.dart';
import '../widgets/campaign_detail_skeleton.dart';
import 'edit_my_campaign_screen.dart';

class MyCampaignDetailScreen extends StatelessWidget {
  const MyCampaignDetailScreen({super.key, required this.campaignId});

  final int campaignId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MyCampaignDetailBloc()
            ..add(MyCampaignDetailStarted(campaignId)),
        ),
        BlocProvider(
          create: (_) => DonorWallBloc()
            ..add(DonorWallStarted(campaignId)),
        ),
      ],
      child: const _MyCampaignDetailView(),
    );
  }
}

class _MyCampaignDetailView extends StatelessWidget {
  const _MyCampaignDetailView();

  Future<void> _refresh(BuildContext context) async {
    context
        .read<MyCampaignDetailBloc>()
        .add(const MyCampaignDetailRefreshed());
    context.read<DonorWallBloc>().add(const DonorWallRefreshed());
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Campaign')),
      body: BlocConsumer<MyCampaignDetailBloc, MyCampaignDetailState>(
        listenWhen: (prev, curr) {
          if (prev is! MyCampaignDetailLoaded ||
              curr is! MyCampaignDetailLoaded) {
            return false;
          }
          return curr.actionError != null &&
              curr.actionError != prev.actionError;
        },
        listener: (context, state) {
          if (state is MyCampaignDetailLoaded &&
              state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.actionError!)),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            MyCampaignDetailInitial() || MyCampaignDetailLoading() =>
              const ShimmerGroup(child: CampaignDetailSkeleton()),
            MyCampaignDetailFailure() => _FailureView(
                message: state.message,
                onRetry: () => _refresh(context),
              ),
            MyCampaignDetailLoaded() => _LoadedBody(
                campaign: state.campaign,
                onRefresh: () => _refresh(context),
              ),
          };
        },
      ),
    );
  }
}

// Loaded body — hero image, title, progress, Manage card, donor wall
class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.campaign,
    required this.onRefresh,
  });

  final Campaign campaign;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          // Hero image — no SliverAppBar, no back button overlay.
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: _HeroImage(url: campaign.imageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatusPill(campaign: campaign),
                      const SizedBox(width: 8),
                      Text(
                        'by ${campaign.ownerDisplayName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _ProgressBlock(campaign: campaign),
                  const SizedBox(height: 24),

                  Text(
                    'Manage',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const _ManageCard(),

                  const SizedBox(height: 24),

                  Text(
                    'About this campaign',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campaign.description.isEmpty
                        ? 'No description provided.'
                        : campaign.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  DonorWallSection(
                    campaignId: campaign.id,
                    campaignTitle: campaign.title,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Manage card — its own widget so it reacts to isActioning independently
class _ManageCard extends StatelessWidget {
  const _ManageCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCampaignDetailBloc, MyCampaignDetailState>(
      builder: (context, state) {
        if (state is! MyCampaignDetailLoaded) {
          return const SizedBox.shrink();
        }

        final campaign = state.campaign;
        final isActioning = state.isActioning;

        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit campaign'),
                trailing: const Icon(Icons.chevron_right),
                enabled: !isActioning,
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EditMyCampaignScreen(
                        campaignId: campaign.id,
                      ),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    context
                        .read<MyCampaignDetailBloc>()
                        .add(const MyCampaignDetailRefreshed());
                  }
                },
              ),
              if (_showSubmitForReview(campaign))
                _ActionTile(
                  icon: Icons.send_outlined,
                  title: 'Submit for review',
                  subtitle:
                      'Admins will review and approve this campaign.',
                  loading: isActioning,
                  onTap: () => _confirm(
                    context,
                    title: 'Submit for review?',
                    body:
                        'Your campaign will be sent to admins for review.',
                    onConfirm: () => context
                        .read<MyCampaignDetailBloc>()
                        .add(const MyCampaignDetailSubmitForReview()),
                  ),
                ),
              if (_showCancelSubmission(campaign))
                _ActionTile(
                  icon: Icons.undo_outlined,
                  title: 'Cancel submission',
                  subtitle: 'Return to draft and keep editing.',
                  loading: isActioning,
                  onTap: () => context
                      .read<MyCampaignDetailBloc>()
                      .add(const MyCampaignDetailCancelSubmission()),
                ),
              if (_showMarkComplete(campaign))
                _ActionTile(
                  icon: Icons.check_circle_outline,
                  title: 'Mark as complete',
                  subtitle: 'Stop accepting donations for this campaign.',
                  loading: isActioning,
                  onTap: () => _confirm(
                    context,
                    title: 'Mark as complete?',
                    body:
                        'Donations will no longer be accepted. This cannot be undone.',
                    onConfirm: () => context
                        .read<MyCampaignDetailBloc>()
                        .add(const MyCampaignDetailMarkComplete()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Helpers
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (campaign.status) {
      'DRAFT' => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      'PENDING_REVIEW' => (const Color(0xFFFFF3C4), const Color(0xFF8A6100)),
      'ACTIVE' => (const Color(0xFFD6F5DD), const Color(0xFF166534)),
      'COMPLETED' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'REJECTED' => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        campaign.statusLabel,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (url == null || url!.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          Container(color: scheme.surfaceContainerHighest),
      errorWidget: (_, __, ___) => Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ETB ${Formatters.money(campaign.raisedAmount)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of ETB ${Formatters.money(campaign.targetAmount)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: campaign.progressFraction,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${campaign.progressPercent.toStringAsFixed(0)}% funded',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${campaign.donationCount} '
                '${campaign.donationCount == 1 ? "donation" : "donations"}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _showSubmitForReview(Campaign c) => c.status == 'DRAFT';
bool _showCancelSubmission(Campaign c) => c.status == 'PENDING_REVIEW';
bool _showMarkComplete(Campaign c) => c.status == 'ACTIVE';

Future<void> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (confirmed == true) onConfirm();
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      enabled: !loading,
      onTap: onTap,
    );
  }
}