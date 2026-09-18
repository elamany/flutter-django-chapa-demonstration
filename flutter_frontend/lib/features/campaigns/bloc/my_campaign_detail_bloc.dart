import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/campaign_repository.dart';
import 'my_campaign_detail_event.dart';
import 'my_campaign_detail_state.dart';

class MyCampaignDetailBloc
    extends Bloc<MyCampaignDetailEvent, MyCampaignDetailState> {
  MyCampaignDetailBloc({CampaignRepository? repository})
      : _repository = repository ?? CampaignRepository(),
        super(const MyCampaignDetailInitial()) {
    on<MyCampaignDetailStarted>(_onStarted);
    on<MyCampaignDetailRefreshed>(_onRefreshed);
  }

  final CampaignRepository _repository;
  int? _currentId;

  Future<void> _onStarted(
    MyCampaignDetailStarted event,
    Emitter<MyCampaignDetailState> emit,
  ) async {
    _currentId = event.id;
    emit(const MyCampaignDetailLoading());

    try {
      final campaign = await _repository.myCampaignDetail(event.id);
      emit(MyCampaignDetailLoaded(campaign));
    } on ApiException catch (e) {
      emit(MyCampaignDetailFailure(e.message));
    }
  }

  Future<void> _onRefreshed(
    MyCampaignDetailRefreshed event,
    Emitter<MyCampaignDetailState> emit,
  ) async {
    final id = _currentId;
    if (id == null) return;

    try {
      final campaign = await _repository.myCampaignDetail(id);
      emit(MyCampaignDetailLoaded(campaign));
    } on ApiException catch (e) {
      emit(MyCampaignDetailFailure(e.message));
    }
  }
}