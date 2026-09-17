import 'package:flutter/material.dart';

import '../../../core/widgets/shimmer_box.dart';

class CampaignCardSkeleton extends StatelessWidget {
  const CampaignCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final _ = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonBox(
              borderRadius: 0,
              height: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title (two lines)
                const SkeletonBox(height: 18, width: 220),
                const SizedBox(height: 8),
                const SkeletonBox(height: 18, width: 140),
                const SizedBox(height: 12),
                // Owner line
                SkeletonBox(
                  height: 12,
                  width: 100,
                  borderRadius: 6,
                ),
                const SizedBox(height: 16),
                // Progress bar
                SkeletonBox(
                  height: 6,
                  borderRadius: 3,
                ),
                const SizedBox(height: 10),
                // Raised / target row
                Row(
                  children: [
                    const SkeletonBox(height: 14, width: 90),
                    const Spacer(),
                    const SkeletonBox(height: 12, width: 70),
                  ],
                ),
                const SizedBox(height: 8),
                // Donation count
                const SkeletonBox(height: 12, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}