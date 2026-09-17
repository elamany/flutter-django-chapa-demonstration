import 'package:equatable/equatable.dart';

import '../data/models/campaign.dart';


sealed class CampaignListState extends Equatable {
  const CampaignListState();

  @override
  List<Object?> get props => [];
}

/// Before anything happens.
final class CampaignListInitial extends CampaignListState {
  const CampaignListInitial();
}

/// Initial load (or filter change). Full-screen spinner.
final class CampaignListLoading extends CampaignListState {
  const CampaignListLoading();
}

/// Data ready. `campaigns` may be empty (no campaigns match the filter).
///
/// `isLoadingMore` is true when appending page N+1, so the UI can show
/// a bottom-of-list spinner without wiping the existing items.
final class CampaignListLoaded extends CampaignListState {
  final List<Campaign> campaigns;
  final String? statusFilter;
  final int currentPage;
  final bool hasNext;
  final bool isLoadingMore;

  const CampaignListLoaded({
    required this.campaigns,
    required this.statusFilter,
    required this.currentPage,
    required this.hasNext,
    this.isLoadingMore = false,
  });

  CampaignListLoaded copyWith({
    List<Campaign>? campaigns,
    String? statusFilter,
    int? currentPage,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return CampaignListLoaded(
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

/// Load failed.
final class CampaignListFailure extends CampaignListState {
  final String message;

  const CampaignListFailure(this.message);

  @override
  List<Object?> get props => [message];
}