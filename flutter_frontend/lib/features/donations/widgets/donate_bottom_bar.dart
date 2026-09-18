import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../../campaigns/data/models/campaign.dart';

/// Sticky bar pinned to the bottom of the campaign detail screen.
///
/// Shows campaign progress on the left and a Donate button on the right.
/// Tapping Donate calls [onDonate].
class DonateBottomBar extends StatelessWidget {
  const DonateBottomBar({
    super.key,
    required this.campaign,
    required this.onDonate,
  });

  final Campaign campaign;
  final VoidCallback onDonate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDonate = campaign.isActive && !campaign.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              // Compact progress summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ETB ${Formatters.money(campaign.raisedAmount)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ETB ${Formatters.money(campaign.targetAmount)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Donate button
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                onPressed: canDonate ? onDonate : null,
                icon: const Icon(Icons.favorite_outline, size: 18),
                label: Text(
                  canDonate ? 'Donate' : 'Closed',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,    
                  foregroundColor: Colors.white,   
                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}