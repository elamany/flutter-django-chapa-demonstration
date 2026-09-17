import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/campaign_repository.dart';
import 'campaign_list_event.dart';
import 'campaign_list_state.dart';

class CampaignListBloc extends Bloc<CampaignListEvent, CampaignListState> {
  CampaignListBloc({CampaignRepository? repository})
      : _repository = repository ?? CampaignRepository(),
        super(const CampaignListInitial()) {
    on<CampaignListStarted>(_onStarted);
    on<CampaignListRefreshed>(_onRefreshed);
    on<CampaignListLoadMore>(_onLoadMore);
    on<CampaignListFilterChanged>(_onFilterChanged);
  }

  final CampaignRepository _repository;

  // ---------------------------------------------------------------------------
  // Started — initial load, or reload after filter change
  // ---------------------------------------------------------------------------
  Future<void> _onStarted(
    CampaignListStarted event,
    Emitter<CampaignListState> emit,
  ) async {
    // Preserve the current filter if we already have one.
    final previous = state;
    final statusFilter =
        previous is CampaignListLoaded ? previous.statusFilter : null;

    emit(const CampaignListLoading());

    try {
      final page = await _repository.list(status: statusFilter, page: 1);
      emit(
        CampaignListLoaded(
          campaigns: page.results,
          statusFilter: statusFilter,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      emit(CampaignListFailure(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Refreshed — reload page 1 with the current filter, keep list visible
  // ---------------------------------------------------------------------------
  Future<void> _onRefreshed(
    CampaignListRefreshed event,
    Emitter<CampaignListState> emit,
  ) async {
    final previous = state;
    final statusFilter = previous is CampaignListLoaded ? previous.statusFilter : null;

    try {
      final page = await _repository.list(status: statusFilter, page: 1);
      emit(
        CampaignListLoaded(
          campaigns: page.results,
          statusFilter: statusFilter,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      // Keep whatever we had; just surface the error via a Failure state
      // so the UI can show a snackbar. Simpler: fall back to Failure.
      emit(CampaignListFailure(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Load more — pagination
  // ---------------------------------------------------------------------------
  Future<void> _onLoadMore(
    CampaignListLoadMore event,
    Emitter<CampaignListState> emit,
  ) async {
    final current = state;
    if (current is! CampaignListLoaded) return;
    if (!current.hasNext) return;
    if (current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));

    final nextPage = current.currentPage + 1;

    try {
      final page = await _repository.list(
        status: current.statusFilter,
        page: nextPage,
      );

      emit(
        current.copyWith(
          campaigns: [...current.campaigns, ...page.results],
          currentPage: nextPage,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      // Keep the existing list, just drop the spinner. Optionally surface
      // the error — for now we silently swallow it, which is fine for
      // infinite scroll (user can pull-to-refresh).
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  // ---------------------------------------------------------------------------
  // Filter changed — reset to page 1
  // ---------------------------------------------------------------------------
  Future<void> _onFilterChanged(
    CampaignListFilterChanged event,
    Emitter<CampaignListState> emit,
  ) async {
    final current = state;
    final currentFilter =
        current is CampaignListLoaded ? current.statusFilter : null;

    if (event.status == currentFilter) return;

    emit(const CampaignListLoading());

    try {
      final page = await _repository.list(
        status: event.status,
        page: 1,
      );
      emit(
        CampaignListLoaded(
          campaigns: page.results,
          statusFilter: event.status,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      emit(CampaignListFailure(e.message));
    }
  }
}