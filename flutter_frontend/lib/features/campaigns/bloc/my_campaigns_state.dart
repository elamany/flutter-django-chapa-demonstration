import 'package:equatable/equatable.dart';

import '../data/models/campaign.dart';

sealed class MyCampaignsState extends Equatable {
  const MyCampaignsState();

  @override
  List<Object?> get props => [];
}

final class MyCampaignsInitial extends MyCampaignsState {
  const MyCampaignsInitial();
}

final class MyCampaignsLoading extends MyCampaignsState {
  const MyCampaignsLoading();
}

final class MyCampaignsLoaded extends MyCampaignsState {
  final List<Campaign> campaigns;
  final String? statusFilter;
  final int currentPage;
  final bool hasNext;
  final bool isLoadingMore;

  const MyCampaignsLoaded({
    required this.campaigns,
    required this.statusFilter,
    required this.currentPage,
    required this.hasNext,
    this.isLoadingMore = false,
  });

  MyCampaignsLoaded copyWith({
    List<Campaign>? campaigns,
    String? statusFilter,
    int? currentPage,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return MyCampaignsLoaded(
      campaigns: campaigns ?? this.campaigns,
      statusFilter: statusFilter ?? this.statusFilter,
      currentPage: currentPage ?? this.currentPage,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        campaigns,
        statusFilter,
        currentPage,
        hasNext,
        isLoadingMore,
      ];
}

final class MyCampaignsFailure extends MyCampaignsState {
  final String message;

  const MyCampaignsFailure(this.message);

  @override
  List<Object?> get props => [message];
}