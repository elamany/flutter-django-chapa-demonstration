import 'package:equatable/equatable.dart';

sealed class CampaignDonorsEvent extends Equatable {
  const CampaignDonorsEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load — resets to page 1.
final class CampaignDonorsStarted extends CampaignDonorsEvent {
  final int campaignId;

  const CampaignDonorsStarted(this.campaignId);

  @override
  List<Object?> get props => [campaignId];
}

/// Pull-to-refresh — reloads page 1 with the current campaign id.
final class CampaignDonorsRefreshed extends CampaignDonorsEvent {
  const CampaignDonorsRefreshed();
}

/// Infinite scroll — fetch the next page and append.
final class CampaignDonorsLoadMore extends CampaignDonorsEvent {
  const CampaignDonorsLoadMore();
}