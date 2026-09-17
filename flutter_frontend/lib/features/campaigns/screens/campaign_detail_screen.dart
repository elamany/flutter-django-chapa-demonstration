import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/format.dart';
import '../bloc/campaign_detail_bloc.dart';
import '../bloc/campaign_detail_event.dart';
import '../bloc/campaign_detail_state.dart';
import '../data/models/campaign.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../widgets/campaign_detail_skeleton.dart';

class CampaignDetailScreen extends StatelessWidget {
  const CampaignDetailScreen({
    super.key,
    required this.campaignId,
  });

  final int campaignId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CampaignDetailBloc()
        ..add(CampaignDetailStarted(campaignId)),
      child: const _CampaignDetailView(),
    );
  }
}

class _CampaignDetailView extends StatelessWidget {
  const _CampaignDetailView();

  Future<void> _refresh(BuildContext context) async {
    context.read<CampaignDetailBloc>().add(const CampaignDetailRefreshed());
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<CampaignDetailBloc, CampaignDetailState>(
        builder: (context, state) {
          return switch (state) {
            CampaignDetailInitial() || CampaignDetailLoading() =>
              const _DetailSkeletonScaffold(),
            CampaignDetailFailure() => _FailureScaffold(message: state.message),
            CampaignDetailLoaded() => _LoadedBody(
                campaign: state.campaign,
                onRefresh: () => _refresh(context),
              ),
          };
        },
      ),
    );
  }
}

// Loading
class _DetailSkeletonScaffold extends StatelessWidget {
  const _DetailSkeletonScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const ShimmerGroup(child: CampaignDetailSkeleton()),
    );
  }
}

// Failure
class _FailureScaffold extends StatelessWidget {
  const _FailureScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
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
                onPressed: () {
                  context
                      .read<CampaignDetailBloc>()
                      .add(const CampaignDetailRefreshed());
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Loaded
class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.campaign,
    required this.onRefresh,
  });

  final Campaign campaign;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(url: campaign.imageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          campaign.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (campaign.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              color: scheme.onTertiaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'by ${campaign.ownerDisplayName}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Progress block
                  _ProgressBlock(campaign: campaign),
                  const SizedBox(height: 24),

                  // Description
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
                  const SizedBox(height: 96), // space for the bottom bar
                ],
              ),
            ),
          ),
        ],
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
          size: 72,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, _) =>
          Container(color: scheme.surfaceContainerHighest),
      errorWidget: (_, _, _) => Container(
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
                  'raised of ETB ${Formatters.money(campaign.targetAmount)}',
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