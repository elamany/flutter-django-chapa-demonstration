import 'package:equatable/equatable.dart';

sealed class MyCampaignDetailEvent extends Equatable {
  const MyCampaignDetailEvent();

  @override
  List<Object?> get props => [];
}

final class MyCampaignDetailStarted extends MyCampaignDetailEvent {
  final int id;
  const MyCampaignDetailStarted(this.id);

  @override
  List<Object?> get props => [id];
}

final class MyCampaignDetailRefreshed extends MyCampaignDetailEvent {
  const MyCampaignDetailRefreshed();
}

final class MyCampaignDetailSubmitForReview extends MyCampaignDetailEvent {
  const MyCampaignDetailSubmitForReview();
}

final class MyCampaignDetailCancelSubmission extends MyCampaignDetailEvent {
  const MyCampaignDetailCancelSubmission();
}

final class MyCampaignDetailMarkComplete extends MyCampaignDetailEvent {
  const MyCampaignDetailMarkComplete();
}