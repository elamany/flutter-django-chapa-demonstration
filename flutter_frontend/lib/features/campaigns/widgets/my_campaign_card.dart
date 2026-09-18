import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';
import '../data/models/campaign.dart';

class MyCampaignCard extends StatelessWidget {
  const MyCampaignCard({
    super.key,
    required this.campaign,
    required this.onTap,
  });

  final Campaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusStyle(campaign.status, scheme);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(url: campaign.imageUrl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusPill(
                          label: campaign.statusLabel,
                          bg: status.bg,
                          fg: status.fg,
                        ),
                        const Spacer(),
                        Text(
                          Formatters.relativeTime(campaign.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      campaign.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ETB ${Formatters.money(campaign.raisedAmount)} '
                      'of ETB ${Formatters.money(campaign.targetAmount)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: campaign.progressFraction,
                        minHeight: 5,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static ({Color bg, Color fg}) _statusStyle(
    String status,
    ColorScheme scheme,
  ) {
    switch (status) {
      case 'DRAFT':
        return (
          bg: scheme.surfaceContainerHighest,
          fg: scheme.onSurfaceVariant,
        );
      case 'PENDING_REVIEW':
        return (
          bg: const Color(0xFFFFF3C4),
          fg: const Color(0xFF8A6100),
        );
      case 'ACTIVE':
        return (
          bg: const Color(0xFFD6F5DD),
          fg: const Color(0xFF166534),
        );
      case 'COMPLETED':
        return (
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1E40AF),
        );
      case 'REJECTED':
        return (
          bg: scheme.errorContainer,
          fg: scheme.onErrorContainer,
        );
      default:
        return (
          bg: scheme.surfaceContainerHighest,
          fg: scheme.onSurfaceVariant,
        );
    }
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 110,
      height: 140,
      child: url == null || url!.isEmpty
          ? Container(
              color: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_outlined,
                color: scheme.onSurfaceVariant,
              ),
            )
          : CachedNetworkImage(
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
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}