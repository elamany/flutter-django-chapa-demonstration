import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/models/campaign.dart';
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
    on<MyCampaignDetailSubmitForReview>(_onSubmitForReview);
    on<MyCampaignDetailCancelSubmission>(_onCancelSubmission);
    on<MyCampaignDetailMarkComplete>(_onMarkComplete);
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

  Future<void> _onSubmitForReview(
    MyCampaignDetailSubmitForReview event,
    Emitter<MyCampaignDetailState> emit,
  ) =>
      _runAction(emit, (repo, id) => repo.submitForReview(id));

  Future<void> _onCancelSubmission(
    MyCampaignDetailCancelSubmission event,
    Emitter<MyCampaignDetailState> emit,
  ) =>
      _runAction(emit, (repo, id) => repo.cancelSubmission(id));

  Future<void> _onMarkComplete(
    MyCampaignDetailMarkComplete event,
    Emitter<MyCampaignDetailState> emit,
  ) =>
      _runAction(emit, (repo, id) => repo.markComplete(id));

  Future<void> _runAction(
    Emitter<MyCampaignDetailState> emit,
    Future<Campaign> Function(CampaignRepository, int) action,
  ) async {
    final current = state;
    final id = _currentId;
    if (current is! MyCampaignDetailLoaded || id == null) return;

    emit(current.copyWith(isActioning: true, clearError: true));

    try {
      final updated = await action(_repository, id);
      emit(MyCampaignDetailLoaded(updated));
    } on ApiException catch (e) {
      emit(current.copyWith(isActioning: false, actionError: e.message));
    }
  }

}