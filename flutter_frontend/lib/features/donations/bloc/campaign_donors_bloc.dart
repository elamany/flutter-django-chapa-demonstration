import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/donation_repository.dart';
import 'campaign_donors_event.dart';
import 'campaign_donors_state.dart';

class CampaignDonorsBloc
    extends Bloc<CampaignDonorsEvent, CampaignDonorsState> {
  CampaignDonorsBloc({DonationRepository? repository})
      : _repository = repository ?? DonationRepository(),
        super(const CampaignDonorsInitial()) {
    on<CampaignDonorsStarted>(_onStarted);
    on<CampaignDonorsRefreshed>(_onRefreshed);
    on<CampaignDonorsLoadMore>(_onLoadMore);
  }

  final DonationRepository _repository;

  int? _campaignId;

  Future<void> _onStarted(
    CampaignDonorsStarted event,
    Emitter<CampaignDonorsState> emit,
  ) async {
    _campaignId = event.campaignId;
    emit(const CampaignDonorsLoading());

    try {
      final page = await _repository.listPublicDonations(
        campaignId: event.campaignId,
        page: 1,
      );
      emit(
        CampaignDonorsLoaded(
          donations: page.results,
          totalCount: page.count,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      emit(CampaignDonorsFailure(e.message));
    }
  }

  Future<void> _onRefreshed(
    CampaignDonorsRefreshed event,
    Emitter<CampaignDonorsState> emit,
  ) async {
    final id = _campaignId;
    if (id == null) return;

    try {
      final page = await _repository.listPublicDonations(
        campaignId: id,
        page: 1,
      );
      emit(
        CampaignDonorsLoaded(
          donations: page.results,
          totalCount: page.count,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      emit(CampaignDonorsFailure(e.message));
    }
  }

  Future<void> _onLoadMore(
    CampaignDonorsLoadMore event,
    Emitter<CampaignDonorsState> emit,
  ) async {
    final current = state;
    if (current is! CampaignDonorsLoaded) return;
    if (!current.hasNext) return;
    if (current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));

    final nextPage = current.currentPage + 1;

    try {
      final page = await _repository.listPublicDonations(
        campaignId: _campaignId!,
        page: nextPage,
      );

      emit(
        current.copyWith(
          donations: [...current.donations, ...page.results],
          currentPage: nextPage,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      );
    } on ApiException {
      // Keep the existing list — the user can pull-to-refresh.
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}