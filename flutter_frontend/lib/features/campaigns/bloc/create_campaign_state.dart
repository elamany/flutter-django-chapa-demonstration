import 'package:equatable/equatable.dart';

import '../data/models/campaign.dart';

sealed class CreateCampaignState extends Equatable {
  const CreateCampaignState();

  @override
  List<Object?> get props => [];
}

final class CreateCampaignIdle extends CreateCampaignState {
  const CreateCampaignIdle();
}

final class CreateCampaignLoading extends CreateCampaignState {
  const CreateCampaignLoading();
}

final class CreateCampaignSuccess extends CreateCampaignState {
  final Campaign campaign;

  const CreateCampaignSuccess(this.campaign);

  @override
  List<Object?> get props => [campaign];
}

final class CreateCampaignFailure extends CreateCampaignState {
  final String message;

  const CreateCampaignFailure(this.message);

  @override
  List<Object?> get props => [message];
}