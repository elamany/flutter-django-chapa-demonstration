import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/campaign_repository.dart';
import 'campaign_detail_event.dart';
import 'campaign_detail_state.dart';

class CampaignDetailBloc extends Bloc<CampaignDetailEvent, CampaignDetailState> {
  CampaignDetailBloc({CampaignRepository? repository})
      : _repository = repository ?? CampaignRepository(),
        super(const CampaignDetailInitial()) {
    on<CampaignDetailStarted>(_onStarted);
    on<CampaignDetailRefreshed>(_onRefreshed);
  }

  final CampaignRepository _repository;

  int? _currentId;

  Future<void> _onStarted(
    CampaignDetailStarted event,
    Emitter<CampaignDetailState> emit,
  ) async {
    _currentId = event.id;
    emit(const CampaignDetailLoading());

    try {
      final campaign = await _repository.detail(event.id);
      emit(CampaignDetailLoaded(campaign));
    } on ApiException catch (e) {
      emit(CampaignDetailFailure(e.message));
    }
  }

  Future<void> _onRefreshed(
    CampaignDetailRefreshed event,
    Emitter<CampaignDetailState> emit,
  ) async {
    final id = _currentId;
    if (id == null) return;

    try {
      final campaign = await _repository.detail(id);
      emit(CampaignDetailLoaded(campaign));
    } on ApiException catch (e) {
      emit(CampaignDetailFailure(e.message));
    }
  }
}