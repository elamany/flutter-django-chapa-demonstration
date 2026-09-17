import 'package:equatable/equatable.dart';

sealed class CampaignListEvent extends Equatable {
  const CampaignListEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load. Also used when the status filter changes.
final class CampaignListStarted extends CampaignListEvent {
  const CampaignListStarted();
}

/// Pull-to-refresh. Reloads page 1 with the current filter.
final class CampaignListRefreshed extends CampaignListEvent {
  const CampaignListRefreshed();
}

/// Infinite scroll — fetch the next page and append.
final class CampaignListLoadMore extends CampaignListEvent {
  const CampaignListLoadMore();
}

/// Change status filter. `null` means "all" (ACTIVE + COMPLETED).
final class CampaignListFilterChanged extends CampaignListEvent {
  final String? status;

  const CampaignListFilterChanged(this.status);

  @override
  List<Object?> get props => [status];
}