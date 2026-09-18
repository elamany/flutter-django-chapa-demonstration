import 'package:equatable/equatable.dart';

sealed class MyCampaignsEvent extends Equatable {
  const MyCampaignsEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load — no filter, page 1.
final class MyCampaignsStarted extends MyCampaignsEvent {
  const MyCampaignsStarted();
}

/// Tab switched. `status` is null for "All".
final class MyCampaignsStatusChanged extends MyCampaignsEvent {
  final String? status;

  const MyCampaignsStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

/// Pull-to-refresh — reload page 1, keep current status filter.
final class MyCampaignsRefreshed extends MyCampaignsEvent {
  const MyCampaignsRefreshed();
}

/// Infinite scroll — fetch next page.
final class MyCampaignsLoadMore extends MyCampaignsEvent {
  const MyCampaignsLoadMore();
}