import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/format.dart';
import '../bloc/donor_latest_5_list_wall_bloc.dart';
import '../bloc/donorr_latest_5_list_wall_state.dart';
import '../data/models/donation.dart';
import '../screens/campaign_donors_screen.dart';

/// Compact donor wall section for the campaign detail screen.
///
/// Shows the 5 most recent donations plus a "See all" link that
/// pushes the full-screen list.
class DonorWallSection extends StatelessWidget {
  const DonorWallSection({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
  });

  final int campaignId;
  final String campaignTitle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DonorWallBloc, DonorWallState>(
      builder: (context, state) {
        return switch (state) {
          DonorWallInitial() || DonorWallLoading() =>
            const _DonorWallSkeleton(),
          DonorWallFailure() => const SizedBox.shrink(),
          DonorWallLoaded() => state.donations.isEmpty
              ? const SizedBox.shrink()
              : _DonorWallList(
                  donations: state.donations,
                  onSeeAll: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CampaignDonorsScreen(
                          campaignId: campaignId,
                          campaignTitle: campaignTitle,
                        ),
                      ),
                    );
                  },
                ),
        };
      },
    );
  }
}

class _DonorWallList extends StatelessWidget {
  const _DonorWallList({
    required this.donations,
    required this.onSeeAll,
  });

  final List<Donation> donations;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent donations',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...donations.map((d) => _DonationTile(donation: d)),
      ],
    );
  }
}

class _DonationTile extends StatelessWidget {
  const _DonationTile({required this.donation});

  final Donation donation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = donation.name.isEmpty
        ? '?'
        : donation.name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: donation.isAnonymous
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer,
            child: donation.isAnonymous
                ? Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
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
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DonorWallSkeleton extends StatelessWidget {
  const _DonorWallSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, height: 18, child: block),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 100, height: 12, child: block),
                    const SizedBox(height: 6),
                    SizedBox(width: 60, height: 10, child: block),
                  ],
                ),
              ),
              SizedBox(width: 60, height: 14, child: block),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}