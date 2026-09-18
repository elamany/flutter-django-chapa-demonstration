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
import '../widgets/campaign_detail_skeleton.dart';

class MyCampaignDetailScreen extends StatelessWidget {
  const MyCampaignDetailScreen({
    super.key,
    required this.campaignId,
  });

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
    return BlocBuilder<MyCampaignDetailBloc, MyCampaignDetailState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Campaign'),
          ),
          body: switch (state) {
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
          },
        );
      },
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.campaign,
    required this.onRefresh,
  });

  final dynamic campaign;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(url: campaign.imageUrl as String?),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.title as String,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _ProgressBlock(campaign: campaign),
                  const SizedBox(height: 24),

                  // Manage actions — placeholder for now
                  Text(
                    'Manage',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: const Text('Edit campaign'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: const Text('Campaign actions'),
                          subtitle: const Text('Submit, cancel, complete…'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Recent donations',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DonorWallSection(
                    campaignId: campaign.id as int,
                    campaignTitle: campaign.title as String,
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

  final dynamic campaign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final raised = campaign.raisedAmount as double;
    final target = campaign.targetAmount as double;
    final progress = campaign.progressFraction as double;
    final percent = campaign.progressPercent as double;
    final count = campaign.donationCount as int;

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
                'ETB ${Formatters.money(raised)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of ETB ${Formatters.money(target)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${percent.toStringAsFixed(0)}% funded',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$count ${count == 1 ? "donation" : "donations"}',
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