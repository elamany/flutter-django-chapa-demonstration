import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/campaign_repository.dart';
import 'my_campaigns_event.dart';
import 'my_campaigns_state.dart';

class MyCampaignsBloc extends Bloc<MyCampaignsEvent, MyCampaignsState> {
  MyCampaignsBloc({CampaignRepository? repository})
      : _repository = repository ?? CampaignRepository(),
        super(const MyCampaignsInitial()) {
    on<MyCampaignsStarted>(_onStarted);
    on<MyCampaignsStatusChanged>(_onStatusChanged);
    on<MyCampaignsRefreshed>(_onRefreshed);
    on<MyCampaignsLoadMore>(_onLoadMore);
  }

  final CampaignRepository _repository;

  Future<void> _onStarted(
    MyCampaignsStarted event,
    Emitter<MyCampaignsState> emit,
  ) async {
    emit(const MyCampaignsLoading());
    await _fetchFirstPage(emit, status: null);
  }

  Future<void> _onStatusChanged(
    MyCampaignsStatusChanged event,
    Emitter<MyCampaignsState> emit,
  ) async {
    final previous = state;
    final currentFilter =
        previous is MyCampaignsLoaded ? previous.statusFilter : null;

    if (event.status == currentFilter) return;

    emit(const MyCampaignsLoading());
    await _fetchFirstPage(emit, status: event.status);
  }

  Future<void> _onRefreshed(
    MyCampaignsRefreshed event,
    Emitter<MyCampaignsState> emit,
  ) async {
    final previous = state;
    final status =
        previous is MyCampaignsLoaded ? previous.statusFilter : null;

    try {
      final page = await _repository.myCampaigns(status: status, page: 1);
      emit(
        MyCampaignsLoaded(
          campaigns: page.results,
          statusFilter: status,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      emit(MyCampaignsFailure(e.message));
    }
  }

  Future<void> _onLoadMore(
    MyCampaignsLoadMore event,
    Emitter<MyCampaignsState> emit,
  ) async {
    final current = state;
    if (current is! MyCampaignsLoaded) return;
    if (!current.hasNext) return;
    if (current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));

    final nextPage = current.currentPage + 1;

    try {
      final page = await _repository.myCampaigns(
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
    } on ApiException {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _fetchFirstPage(
    Emitter<MyCampaignsState> emit, {
    required String? status,
  }) async {
    try {
      final page = await _repository.myCampaigns(status: status, page: 1);
      emit(
        MyCampaignsLoaded(
          campaigns: page.results,
          statusFilter: status,
          currentPage: 1,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      emit(MyCampaignsFailure(e.message));
    }
  }
}