import 'package:equatable/equatable.dart';
import '../data/models/campaign.dart';

sealed class MyCampaignDetailState extends Equatable {
  const MyCampaignDetailState();

  @override
  List<Object?> get props => [];
}

final class MyCampaignDetailInitial extends MyCampaignDetailState {
  const MyCampaignDetailInitial();
}

final class MyCampaignDetailLoading extends MyCampaignDetailState {
  const MyCampaignDetailLoading();
}

final class MyCampaignDetailLoaded extends MyCampaignDetailState {
  final Campaign campaign;
  const MyCampaignDetailLoaded(this.campaign);

  @override
  List<Object?> get props => [campaign];
}

final class MyCampaignDetailFailure extends MyCampaignDetailState {
  final String message;
  const MyCampaignDetailFailure(this.message);

  @override
  List<Object?> get props => [message];
}