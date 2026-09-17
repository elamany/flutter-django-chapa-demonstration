import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A grey block with a shimmer sweep. Compose these into skeletons.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? scheme.surfaceContainerHighest.withValues(alpha:0.6)
          : scheme.surfaceContainerHighest,
      highlightColor: isDark
          ? scheme.surfaceContainerHigh.withValues(alpha: 0.9)
          : scheme.surfaceContainerLow,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Full-screen shimmer wrapper — one Shimmer.fromColors call wrapping many
/// blocks makes the sweep move in sync across the whole skeleton.
class ShimmerGroup extends StatelessWidget {
  const ShimmerGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
          : scheme.surfaceContainerHighest,
      highlightColor: isDark
          ? scheme.surfaceContainerHigh.withValues(alpha: 0.9)
          : scheme.surfaceContainerLow,
      child: child,
    );
  }
}

/// Plain grey block used INSIDE a ShimmerGroup. No own shimmer.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}