import 'package:equatable/equatable.dart';

import '../data/models/campaign.dart';

sealed class CampaignDetailState extends Equatable {
  const CampaignDetailState();

  @override
  List<Object?> get props => [];
}

final class CampaignDetailInitial extends CampaignDetailState {
  const CampaignDetailInitial();
}

final class CampaignDetailLoading extends CampaignDetailState {
  const CampaignDetailLoading();
}

final class CampaignDetailLoaded extends CampaignDetailState {
  final Campaign campaign;

  const CampaignDetailLoaded(this.campaign);

  @override
  List<Object?> get props => [campaign];
}

final class CampaignDetailFailure extends CampaignDetailState {
  final String message;

  const CampaignDetailFailure(this.message);

  @override
  List<Object?> get props => [message];
}