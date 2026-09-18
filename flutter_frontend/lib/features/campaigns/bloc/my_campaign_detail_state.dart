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
  final bool isActioning;
  final String? actionError;

  const MyCampaignDetailLoaded(
    this.campaign, {
    this.isActioning = false,
    this.actionError,
  });

  MyCampaignDetailLoaded copyWith({
    Campaign? campaign,
    bool? isActioning,
    String? actionError,
    bool clearError = false,
  }) {
    return MyCampaignDetailLoaded(
      campaign ?? this.campaign,
      isActioning: isActioning ?? this.isActioning,
      actionError: clearError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [campaign, isActioning, actionError];
}

final class MyCampaignDetailFailure extends MyCampaignDetailState {
  final String message;
  const MyCampaignDetailFailure(this.message);

  @override
  List<Object?> get props => [message];
}

