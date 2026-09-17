import 'package:equatable/equatable.dart';

sealed class CampaignDetailEvent extends Equatable {
  const CampaignDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Load the campaign with [id].
final class CampaignDetailStarted extends CampaignDetailEvent {
  final int id;

  const CampaignDetailStarted(this.id);

  @override
  List<Object?> get props => [id];
}

/// Pull-to-refresh on the detail screen.
final class CampaignDetailRefreshed extends CampaignDetailEvent {
  const CampaignDetailRefreshed();
}