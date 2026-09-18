import 'package:equatable/equatable.dart';

import '../data/models/donation.dart';

sealed class CampaignDonorsState extends Equatable {
  const CampaignDonorsState();

  @override
  List<Object?> get props => [];
}

final class CampaignDonorsInitial extends CampaignDonorsState {
  const CampaignDonorsInitial();
}

final class CampaignDonorsLoading extends CampaignDonorsState {
  const CampaignDonorsLoading();
}

final class CampaignDonorsLoaded extends CampaignDonorsState {
  final List<Donation> donations;
  final int totalCount;
  final int currentPage;
  final bool hasNext;
  final bool isLoadingMore;

  const CampaignDonorsLoaded({
    required this.donations,
    required this.totalCount,
    required this.currentPage,
    required this.hasNext,
    this.isLoadingMore = false,
  });

  CampaignDonorsLoaded copyWith({
    List<Donation>? donations,
    int? totalCount,
    int? currentPage,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return CampaignDonorsLoaded(
      donations: donations ?? this.donations,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        donations,
        totalCount,
        currentPage,
        hasNext,
        isLoadingMore,
      ];
}

final class CampaignDonorsFailure extends CampaignDonorsState {
  final String message;

  const CampaignDonorsFailure(this.message);

  @override
  List<Object?> get props => [message];
}