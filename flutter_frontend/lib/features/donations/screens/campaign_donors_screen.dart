import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/format.dart';
import '../bloc/campaign_donors_bloc.dart';
import '../bloc/campaign_donors_event.dart';
import '../bloc/campaign_donors_state.dart';
import '../data/models/donation.dart';

class CampaignDonorsScreen extends StatelessWidget {
  const CampaignDonorsScreen({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
  });

  final int campaignId;
  final String campaignTitle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CampaignDonorsBloc()
        ..add(CampaignDonorsStarted(campaignId)),
      child: _CampaignDonorsView(campaignTitle: campaignTitle),
    );
  }
}

class _CampaignDonorsView extends StatefulWidget {
  const _CampaignDonorsView({required this.campaignTitle});

  final String campaignTitle;

  @override
  State<_CampaignDonorsView> createState() => _CampaignDonorsViewState();
}

class _CampaignDonorsViewState extends State<_CampaignDonorsView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context
          .read<CampaignDonorsBloc>()
          .add(const CampaignDonorsLoadMore());
    }
  }

  Future<void> _refresh() async {
    context
        .read<CampaignDonorsBloc>()
        .add(const CampaignDonorsRefreshed());
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donations'),
      ),
      body: Column(
        children: [
          _Header(campaignTitle: widget.campaignTitle),
          Expanded(
            child: BlocBuilder<CampaignDonorsBloc, CampaignDonorsState>(
              builder: (context, state) {
                return switch (state) {
                  CampaignDonorsInitial() || CampaignDonorsLoading() =>
                    const _DonorsSkeleton(),
                  CampaignDonorsFailure() =>
                    _FailureView(message: state.message, onRetry: _refresh),
                  CampaignDonorsLoaded() => _LoadedView(
                      state: state,
                      scrollController: _scrollController,
                      onRefresh: _refresh,
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Header

class _Header extends StatelessWidget {
  const _Header({required this.campaignTitle});

  final String campaignTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaignTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          BlocBuilder<CampaignDonorsBloc, CampaignDonorsState>(
            buildWhen: (prev, curr) {
              final prevCount =
                  prev is CampaignDonorsLoaded ? prev.totalCount : null;
              final currCount =
                  curr is CampaignDonorsLoaded ? curr.totalCount : null;
              return prevCount != currCount;
            },
            builder: (context, state) {
              final count = state is CampaignDonorsLoaded
                  ? state.totalCount
                  : null;
              return Text(
                count == null
                    ? 'Loading…'
                    : '$count ${count == 1 ? "donation" : "donations"}',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ],
      ),
    );
  }
}

// Loaded list
class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
  });

  final CampaignDonorsLoaded state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (state.donations.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No donations yet.')),
          ],
        ),
      );
    }

    final itemCount = state.donations.length + 1;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == state.donations.length) {
            return _Footer(state: state);
          }
          return _DonationRow(donation: state.donations[index]);
        },
      ),
    );
  }
}

class _DonationRow extends StatelessWidget {
  const _DonationRow({required this.donation});

  final Donation donation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial =
        donation.name.isEmpty ? '?' : donation.name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: donation.isAnonymous
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer,
            child: donation.isAnonymous
                ? Icon(
                    Icons.visibility_off_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    donation.name
                        .split(' ')
                        .map((word) => word.isEmpty
                            ? word
                            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
                        .join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                const SizedBox(height: 2),
                Text(
                  Formatters.relativeTime(donation.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            'ETB ${Formatters.money(donation.amount)}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final CampaignDonorsLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!state.hasNext) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No more donations.')),
      );
    }

    return const SizedBox(height: 24);
  }
}

// Skeleton

class _DonorsSkeleton extends StatelessWidget {
  const _DonorsSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 140, height: 14, child: block),
                  const SizedBox(height: 6),
                  SizedBox(width: 80, height: 10, child: block),
                ],
              ),
            ),
            SizedBox(width: 60, height: 16, child: block),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Failure
// -----------------------------------------------------------------------------

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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