import 'package:equatable/equatable.dart';

import '../data/models/campaign.dart';

sealed class EditCampaignState extends Equatable {
  const EditCampaignState();

  @override
  List<Object?> get props => [];
}

final class EditCampaignInitial extends EditCampaignState {
  const EditCampaignInitial();
}

final class EditCampaignLoading extends EditCampaignState {
  const EditCampaignLoading();
}

final class EditCampaignReady extends EditCampaignState {
  final Campaign campaign;
  final bool submitting;

  const EditCampaignReady(this.campaign, {this.submitting = false});

  EditCampaignReady copyWith({bool? submitting}) =>
      EditCampaignReady(campaign, submitting: submitting ?? this.submitting);

  @override
  List<Object?> get props => [campaign, submitting];
}

final class EditCampaignSuccess extends EditCampaignState {
  final Campaign campaign;

  const EditCampaignSuccess(this.campaign);

  @override
  List<Object?> get props => [campaign];
}

final class EditCampaignFailure extends EditCampaignState {
  final String message;

  const EditCampaignFailure(this.message);

  @override
  List<Object?> get props => [message];
}