import 'package:flutter/material.dart';

import '../../../core/widgets/shimmer_box.dart';

class CampaignDetailSkeleton extends StatelessWidget {
  const CampaignDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Hero image area
        SliverToBoxAdapter(
          child: SizedBox(
            height: 240,
            child: SkeletonBox(
              borderRadius: 0,
              height: double.infinity,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title (two lines)
                const SkeletonBox(height: 26, width: 260),
                const SizedBox(height: 10),
                const SkeletonBox(height: 26, width: 180),
                const SizedBox(height: 12),
                // Owner
                const SkeletonBox(height: 14, width: 120),
                const SizedBox(height: 24),

                // Progress block container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(height: 26, width: 180),
                      const SizedBox(height: 12),
                      SkeletonBox(height: 8, borderRadius: 4),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SkeletonBox(height: 14, width: 90),
                          const Spacer(),
                          const SkeletonBox(height: 14, width: 80),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // About heading
                const SkeletonBox(height: 18, width: 160),
                const SizedBox(height: 12),
                // Description lines
                const SkeletonBox(height: 14, borderRadius: 6),
                const SizedBox(height: 8),
                const SkeletonBox(height: 14, borderRadius: 6),
                const SizedBox(height: 8),
                const SkeletonBox(height: 14, width: 220, borderRadius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}